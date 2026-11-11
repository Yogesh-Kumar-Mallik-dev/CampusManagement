package handler

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"campus/backend/internal/storage"
)

// UploadedPDFMetadata captures file storage attributes
type UploadedPDFMetadata struct {
	FileID        string    `json:"file_id"`
	OriginalName  string    `json:"original_name"`
	Filename      string    `json:"filename"`
	SizeBytes     int64     `json:"size_bytes"`
	SizeFormatted string    `json:"size_formatted"`
	URL           string    `json:"url"`
	SHA256        string    `json:"sha256"`
	UploadedAt    time.Time `json:"uploaded_at"`
}

// UploadHandler manages multipart PDF uploads and binary retrieval
type UploadHandler struct {
	storage  storage.BlobStorage
	mu       sync.RWMutex
	files    map[string][]byte
	metadata map[string]UploadedPDFMetadata
}

// NewUploadHandler creates an UploadHandler using default local storage
func NewUploadHandler(uploadDir string) *UploadHandler {
	store, _ := storage.NewLocalStorage(uploadDir)
	return NewUploadHandlerWithStorage(store)
}

// NewUploadHandlerWithStorage creates an UploadHandler with injected BlobStorage (S3 or Local)
func NewUploadHandlerWithStorage(store storage.BlobStorage) *UploadHandler {
	if store == nil {
		store, _ = storage.NewStorage(storage.StorageConfig{})
	}
	return &UploadHandler{
		storage:  store,
		files:    make(map[string][]byte),
		metadata: make(map[string]UploadedPDFMetadata),
	}
}

// Storage returns the underlying BlobStorage instance
func (h *UploadHandler) Storage() storage.BlobStorage {
	return h.storage
}

// HandleUploadPDF processes multipart POST requests for PDF files
func (h *UploadHandler) HandleUploadPDF(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	w.Header().Set("Content-Type", "application/json")

	// Limit request body to 25 MB
	const maxUploadSize = 25 << 20
	r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)

	if err := r.ParseMultipartForm(maxUploadSize); err != nil {
		http.Error(w, `{"error":"file exceeds 25MB limit or invalid multipart payload"}`, http.StatusBadRequest)
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		// Check fallback field name "pdf"
		file, header, err = r.FormFile("pdf")
		if err != nil {
			http.Error(w, `{"error":"multipart field 'file' or 'pdf' is required"}`, http.StatusBadRequest)
			return
		}
	}
	defer file.Close()

	// Read first 1024 bytes to verify magic header per ISO 32000-1 §7.5.2
	buf := make([]byte, 1024)
	n, err := file.Read(buf)
	if err != nil && err != io.EOF {
		http.Error(w, `{"error":"failed to read uploaded file"}`, http.StatusBadRequest)
		return
	}

	if n < 4 || !bytes.Contains(buf[:n], []byte("%PDF-")) {
		http.Error(w, `{"error":"invalid file signature: only authentic PDF files with %PDF- header are accepted"}`, http.StatusBadRequest)
		return
	}

	// Read remainder of file
	var fullContent bytes.Buffer
	fullContent.Write(buf[:n])
	if _, err := io.Copy(&fullContent, file); err != nil {
		http.Error(w, `{"error":"failed to process file stream"}`, http.StatusInternalServerError)
		return
	}

	fileBytes := fullContent.Bytes()
	sizeBytes := int64(len(fileBytes))

	// Compute SHA-256
	hash := sha256.Sum256(fileBytes)
	hashHex := hex.EncodeToString(hash[:])

	now := time.Now().UTC()
	fileID := fmt.Sprintf("pdf-%d-%s", now.UnixMilli(), hashHex[:8])
	cleanOrigName := filepath.Base(header.Filename)
	if cleanOrigName == "" || cleanOrigName == "." {
		cleanOrigName = fmt.Sprintf("%s.pdf", fileID)
	}
	if !strings.HasSuffix(strings.ToLower(cleanOrigName), ".pdf") {
		cleanOrigName += ".pdf"
	}

	storedFilename := fmt.Sprintf("%s_%s", fileID, cleanOrigName)
	sizeFormatted := storage.FormatFileSize(sizeBytes)
	servingURL := fmt.Sprintf("/api/v1/uploads?id=%s", fileID)

	meta := UploadedPDFMetadata{
		FileID:        fileID,
		OriginalName:  cleanOrigName,
		Filename:      storedFilename,
		SizeBytes:     sizeBytes,
		SizeFormatted: sizeFormatted,
		URL:           servingURL,
		SHA256:        hashHex,
		UploadedAt:    now,
	}

	// Persist to BlobStorage (S3 in production, Local in dev)
	if h.storage != nil {
		_, _ = h.storage.Upload(r.Context(), storedFilename, fileBytes, "application/pdf")
		_, _ = h.storage.Upload(r.Context(), fileID, fileBytes, "application/pdf")
	}

	h.mu.Lock()
	h.files[fileID] = fileBytes
	h.files[storedFilename] = fileBytes
	h.metadata[fileID] = meta
	h.mu.Unlock()

	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(meta)
}

// HandleServeUpload serves uploaded PDF files
func (h *UploadHandler) HandleServeUpload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	id := r.URL.Query().Get("id")
	if id == "" {
		// Try path parameter if trailing slash
		parts := strings.Split(r.URL.Path, "/")
		if len(parts) > 0 {
			id = parts[len(parts)-1]
		}
	}

	if id == "" || id == "uploads" {
		http.Error(w, `{"error":"file id is required"}`, http.StatusBadRequest)
		return
	}

	h.mu.RLock()
	data, ok := h.files[id]
	meta, hasMeta := h.metadata[id]
	h.mu.RUnlock()

	if !ok && h.storage != nil {
		// Retrieve from storage provider (S3 or local filesystem)
		var err error
		data, _, err = h.storage.Download(r.Context(), id)
		if err != nil {
			if hasMeta && meta.Filename != "" {
				data, _, _ = h.storage.Download(r.Context(), meta.Filename)
			}
		}
	}

	if len(data) == 0 {
		http.Error(w, `{"error":"file not found"}`, http.StatusNotFound)
		return
	}

	filename := "document.pdf"
	if hasMeta && meta.OriginalName != "" {
		filename = meta.OriginalName
	} else if strings.HasSuffix(strings.ToLower(id), ".pdf") {
		filename = id
	}

	w.Header().Set("Content-Type", "application/pdf")
	w.Header().Set("Content-Disposition", fmt.Sprintf(`inline; filename="%s"`, filename))
	w.Header().Set("Content-Length", fmt.Sprintf("%d", len(data)))
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(data)
}
