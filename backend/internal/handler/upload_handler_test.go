package handler_test

import (
	"bytes"
	"encoding/json"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"campus/backend/internal/handler"
)

func TestUploadPDFHandler_Success(t *testing.T) {
	h := handler.NewUploadHandler(t.TempDir())

	// Prepare multipart form with valid %PDF- header
	var b bytes.Buffer
	w := multipart.NewWriter(&b)
	part, err := w.CreateFormFile("file", "test_document.pdf")
	if err != nil {
		t.Fatalf("failed to create form file: %v", err)
	}

	validPDFContent := []byte("%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF")
	if _, err := part.Write(validPDFContent); err != nil {
		t.Fatalf("failed to write form file: %v", err)
	}
	_ = w.Close()

	req := httptest.NewRequest(http.MethodPost, "/api/v1/upload/pdf", &b)
	req.Header.Set("Content-Type", w.FormDataContentType())
	rec := httptest.NewRecorder()

	h.HandleUploadPDF(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected status 201, got %d: %s", rec.Code, rec.Body.String())
	}

	var meta handler.UploadedPDFMetadata
	if err := json.NewDecoder(rec.Body).Decode(&meta); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if !strings.HasPrefix(meta.FileID, "pdf-") {
		t.Errorf("expected file_id to start with 'pdf-', got %s", meta.FileID)
	}
	if meta.OriginalName != "test_document.pdf" {
		t.Errorf("expected original_name test_document.pdf, got %s", meta.OriginalName)
	}
	if meta.SizeBytes != int64(len(validPDFContent)) {
		t.Errorf("expected size %d, got %d", len(validPDFContent), meta.SizeBytes)
	}
	if meta.URL == "" {
		t.Errorf("expected non-empty serving url")
	}

	// Verify serving the file back
	getReq := httptest.NewRequest(http.MethodGet, "/api/v1/uploads?id="+meta.FileID, nil)
	getRec := httptest.NewRecorder()
	h.HandleServeUpload(getRec, getReq)

	if getRec.Code != http.StatusOK {
		t.Fatalf("expected status 200 serving upload, got %d: %s", getRec.Code, getRec.Body.String())
	}
	if getRec.Header().Get("Content-Type") != "application/pdf" {
		t.Errorf("expected application/pdf, got %s", getRec.Header().Get("Content-Type"))
	}
	servedBytes, _ := io.ReadAll(getRec.Body)
	if !bytes.Equal(servedBytes, validPDFContent) {
		t.Errorf("served bytes do not match uploaded bytes")
	}
}

func TestUploadPDFHandler_InvalidMagicBytes(t *testing.T) {
	h := handler.NewUploadHandler(t.TempDir())

	var b bytes.Buffer
	w := multipart.NewWriter(&b)
	part, _ := w.CreateFormFile("file", "fake.pdf")
	_, _ = part.Write([]byte("not a real pdf file text content"))
	_ = w.Close()

	req := httptest.NewRequest(http.MethodPost, "/api/v1/upload/pdf", &b)
	req.Header.Set("Content-Type", w.FormDataContentType())
	rec := httptest.NewRecorder()

	h.HandleUploadPDF(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 Bad Request for non-PDF, got %d", rec.Code)
	}
}
