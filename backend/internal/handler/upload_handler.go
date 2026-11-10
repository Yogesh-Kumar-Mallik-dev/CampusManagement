package handler

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
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
	uploadDir string
	mu        sync.RWMutex
	files     map[string][]byte
	metadata  map[string]UploadedPDFMetadata
}

// NewUploadHandler creates an UploadHandler with storage directory and memory fallback
func NewUploadHandler(uploadDir string) *UploadHandler {
	if uploadDir == "" {
		uploadDir = filepath.Join(os.TempDir(), "campus_uploads")
	}
	_ = os.MkdirAll(uploadDir, 0755)

	return &UploadHandler{
		uploadDir: uploadDir,
		files:     make(map[string][]byte),
		metadata:  make(map[string]UploadedPDFMetadata),
	}
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

	// Read first 512 bytes to verify magic header
	buf := make([]byte, 512)
	n, err := file.Read(buf)
	if err != nil && err != io.EOF {
		http.Error(w, `{"error":"failed to read uploaded file"}`, http.StatusBadRequest)
		return
	}

	if n < 4 || !bytes.HasPrefix(buf[:n], []byte("%PDF-")) {
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
	sizeFormatted := formatFileSize(sizeBytes)
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

	// Persist to disk and memory
	diskPath := filepath.Join(h.uploadDir, storedFilename)
	_ = os.WriteFile(diskPath, fileBytes, 0644)

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

	if !ok {
		// Check disk
		diskPath := filepath.Join(h.uploadDir, id)
		var err error
		data, err = os.ReadFile(diskPath)
		if err != nil {
			http.Error(w, `{"error":"file not found"}`, http.StatusNotFound)
			return
		}
	}

	filename := "document.pdf"
	if hasMeta && meta.OriginalName != "" {
		filename = meta.OriginalName
	}

	w.Header().Set("Content-Type", "application/pdf")
	w.Header().Set("Content-Disposition", fmt.Sprintf(`inline; filename="%s"`, filename))
	w.Header().Set("Content-Length", fmt.Sprintf("%d", len(data)))
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(data)
}

func formatFileSize(bytes int64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	div, exp := int64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(bytes)/float64(div), "KMGTPE"[exp])
}
