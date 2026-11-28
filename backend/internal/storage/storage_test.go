package storage

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
)

func TestLocalStorageLifecycle(t *testing.T) {
	tempDir, err := os.MkdirTemp("", "campus_storage_test_*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tempDir)

	store, err := NewLocalStorage(tempDir)
	if err != nil {
		t.Fatalf("failed to create LocalStorage: %v", err)
	}

	if store.Driver() != "local" {
		t.Errorf("expected driver 'local', got '%s'", store.Driver())
	}

	ctx := context.Background()
	testPayload := []byte("%PDF-1.4 test document content")
	key := "test_docs/sample.pdf"

	// 1. Upload
	url, err := store.Upload(ctx, key, testPayload, "application/pdf")
	if err != nil {
		t.Fatalf("failed to upload: %v", err)
	}
	if !strings.Contains(url, "sample.pdf") {
		t.Errorf("expected URL containing key, got %s", url)
	}

	// Verify file on disk
	diskPath := filepath.Join(tempDir, "test_docs", "sample.pdf")
	if _, err := os.Stat(diskPath); err != nil {
		t.Errorf("expected file to exist at %s, got: %v", diskPath, err)
	}

	// 2. Download
	downloaded, contentType, err := store.Download(ctx, key)
	if err != nil {
		t.Fatalf("failed to download: %v", err)
	}
	if string(downloaded) != string(testPayload) {
		t.Errorf("downloaded content mismatch")
	}
	if contentType != "application/pdf" {
		t.Errorf("expected application/pdf, got %s", contentType)
	}

	// 3. Delete
	if err := store.Delete(ctx, key); err != nil {
		t.Fatalf("failed to delete: %v", err)
	}

	// Verify file removed
	if _, err := os.Stat(diskPath); !os.IsNotExist(err) {
		t.Errorf("expected file to be deleted from disk")
	}
}

func TestS3StorageConfigurationAndFallback(t *testing.T) {
	tempDir, err := os.MkdirTemp("", "campus_s3_fallback_*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tempDir)

	cfg := StorageConfig{
		Driver:          "s3",
		LocalDir:        tempDir,
		S3Bucket:        "campus-test-bucket",
		S3Region:        "us-east-1",
		S3Endpoint:      "http://localhost:9000",
		S3AccessKey:     "", // Empty to trigger fallback
		S3SecretKey:     "",
		S3PublicBaseURL: "https://cdn.campus.edu",
	}

	store, err := NewS3Storage(cfg)
	if err != nil {
		t.Fatalf("failed to create S3Storage: %v", err)
	}

	if store.Driver() != "s3" {
		t.Errorf("expected driver 's3', got '%s'", store.Driver())
	}

	ctx := context.Background()
	testPayload := []byte("%PDF-1.4 fallback s3 document")
	key := "ebooks/fallback.pdf"

	// Upload should fall back cleanly to local
	url, err := store.Upload(ctx, key, testPayload, "application/pdf")
	if err != nil {
		t.Fatalf("upload fallback failed: %v", err)
	}
	if url == "" {
		t.Errorf("expected valid URL")
	}

	// Download should retrieve from local fallback
	downloaded, _, err := store.Download(ctx, key)
	if err != nil {
		t.Fatalf("download fallback failed: %v", err)
	}
	if string(downloaded) != string(testPayload) {
		t.Errorf("content mismatch")
	}

	// Delete
	if err := store.Delete(ctx, key); err != nil {
		t.Fatalf("delete fallback failed: %v", err)
	}
}

func TestFormatFileSize(t *testing.T) {
	cases := []struct {
		bytes    int64
		expected string
	}{
		{500, "500 B"},
		{1024, "1.0 KB"},
		{1048576, "1.0 MB"},
		{15728640, "15.0 MB"},
	}

	for _, tc := range cases {
		got := FormatFileSize(tc.bytes)
		if got != tc.expected {
			t.Errorf("FormatFileSize(%d) = %s, expected %s", tc.bytes, got, tc.expected)
		}
	}
}

func TestLocalStorageEdgeAndFactoryBranches(t *testing.T) {
	// Empty baseDir uses home/temp default
	tmpHome := t.TempDir()
	t.Setenv("HOME", tmpHome)
	defStore, err := NewLocalStorage("")
	if err != nil {
		t.Fatalf("NewLocalStorage empty failed: %v", err)
	}
	if defStore.BaseDir() == "" || !strings.Contains(defStore.BaseDir(), ".campus_management") {
		t.Fatalf("unexpected default BaseDir: %s", defStore.BaseDir())
	}

	// Download missing file error
	ctx := context.Background()
	if _, _, err := defStore.Download(ctx, "missing/file.bin"); err == nil {
		t.Fatalf("expected error downloading missing file")
	}

	// Non-pdf download returns application/octet-stream
	if _, err := defStore.Upload(ctx, "notes/readme.txt", []byte("hello"), ""); err != nil {
		t.Fatalf("upload txt failed: %v", err)
	}
	data, ct, err := defStore.Download(ctx, "notes/readme.txt")
	if err != nil || string(data) != "hello" || ct != "application/octet-stream" {
		t.Fatalf("unexpected download txt result: ct=%s err=%v", ct, err)
	}

	// NewStorage factory local & s3
	t.Setenv("STORAGE_DRIVER", "local")
	t.Setenv("STORAGE_LOCAL_DIR", t.TempDir())
	envStore, err := NewStorageFromEnv()
	if err != nil || envStore.Driver() != "local" {
		t.Fatalf("NewStorageFromEnv local failed: err=%v", err)
	}

	t.Setenv("STORAGE_DRIVER", "")
	t.Setenv("STORAGE_LOCAL_DIR", "")
	t.Setenv("CAMPUS_UPLOADS_DIR", t.TempDir())
	t.Setenv("AWS_S3_BUCKET", "aws-bucket")
	t.Setenv("AWS_REGION", "ap-south-1")
	t.Setenv("AWS_ACCESS_KEY_ID", "ak")
	t.Setenv("AWS_SECRET_ACCESS_KEY", "sk")
	t.Setenv("S3_USE_PATH_STYLE", "false")
	envS3, err := NewStorageFromEnv()
	if err != nil || envS3.Driver() != "s3" {
		t.Fatalf("NewStorageFromEnv s3 failed: err=%v", err)
	}

	// NewStorage default empty LocalDir
	defFromCfg, err := NewStorage(StorageConfig{Driver: "local"})
	if err != nil || defFromCfg.Driver() != "local" {
		t.Fatalf("NewStorage default local failed: %v", err)
	}
}

func TestS3StorageHTTPMockLifecycle(t *testing.T) {
	// Missing bucket returns error
	if _, err := NewS3Storage(StorageConfig{}); err == nil {
		t.Fatalf("expected error when S3Bucket is empty")
	}

	var mu sync.Mutex
	objects := map[string][]byte{}
	types := map[string]string{}
	statusMode := 200

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") == "" || r.Header.Get("x-amz-date") == "" {
			w.WriteHeader(http.StatusForbidden)
			return
		}
		if statusMode != 200 {
			w.WriteHeader(statusMode)
			_, _ = w.Write([]byte("mock error"))
			return
		}
		key := r.URL.Path
		mu.Lock()
		defer mu.Unlock()
		switch r.Method {
		case http.MethodPut:
			body, _ := io.ReadAll(r.Body)
			objects[key] = body
			types[key] = r.Header.Get("Content-Type")
			w.WriteHeader(http.StatusOK)
		case http.MethodGet:
			b, ok := objects[key]
			if !ok {
				w.WriteHeader(http.StatusNotFound)
				return
			}
			if ct := types[key]; ct != "" {
				w.Header().Set("Content-Type", ct)
			}
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write(b)
		case http.MethodDelete:
			delete(objects, key)
			w.WriteHeader(http.StatusNoContent)
		}
	}))
	defer srv.Close()

	store, err := NewS3Storage(StorageConfig{
		Driver:          "s3",
		LocalDir:        t.TempDir(),
		S3Bucket:        "test-bucket",
		S3Region:        "",
		S3Endpoint:      srv.URL,
		S3AccessKey:     "AKIA123",
		S3SecretKey:     "SECRET456",
		S3UsePathStyle:  true,
		S3PublicBaseURL: "https://cdn.example.com/",
	})
	if err != nil {
		t.Fatalf("NewS3Storage failed: %v", err)
	}

	ctx := context.Background()
	urlStr, err := store.Upload(ctx, "/docs/test.pdf", []byte("pdfbytes"), "")
	if err != nil {
		t.Fatalf("Upload failed: %v", err)
	}
	if urlStr != "https://cdn.example.com/docs/test.pdf" {
		t.Fatalf("unexpected public URL: %s", urlStr)
	}

	got, ct, err := store.Download(ctx, "docs/test.pdf")
	if err != nil || string(got) != "pdfbytes" || ct != "application/octet-stream" {
		t.Fatalf("unexpected Download result: got=%q ct=%s err=%v", string(got), ct, err)
	}

	if err := store.Delete(ctx, "docs/test.pdf"); err != nil {
		t.Fatalf("Delete failed: %v", err)
	}

	// URL without publicBaseURL
	storeNoCDN, _ := NewS3Storage(StorageConfig{
		S3Bucket:       "test-bucket",
		S3Endpoint:     srv.URL,
		S3AccessKey:    "AKIA123",
		S3SecretKey:    "SECRET456",
		S3UsePathStyle: false,
	})
	if u := storeNoCDN.URL("/a/b.pdf"); u != "/api/v1/uploads?id=a/b.pdf" {
		t.Fatalf("unexpected fallback URL: %s", u)
	}
	if ep, err := storeNoCDN.buildObjectEndpoint("a/b.pdf"); err != nil || !strings.Contains(ep, "test-bucket.") {
		t.Fatalf("unexpected virtual-host endpoint: %s err=%v", ep, err)
	}

	// Error status triggers fallback when localFallback != nil, and direct error when localFallback == nil
	statusMode = 500
	if _, err := store.Upload(ctx, "err/a.pdf", []byte("x"), "application/pdf"); err != nil {
		t.Fatalf("expected fallback upload to succeed, got: %v", err)
	}
	if _, _, err := store.Download(ctx, "err/a.pdf"); err != nil {
		t.Fatalf("expected fallback download to succeed, got: %v", err)
	}
	if err := store.Delete(ctx, "err/a.pdf"); err != nil {
		t.Fatalf("expected fallback delete to succeed, got: %v", err)
	}

	store.localFallback = nil
	if _, err := store.Upload(ctx, "err/b.pdf", []byte("x"), "application/pdf"); err == nil {
		t.Fatalf("expected error on 500 without fallback")
	}
	if _, _, err := store.Download(ctx, "err/b.pdf"); err == nil {
		t.Fatalf("expected error on 500 download without fallback")
	}
	if err := store.Delete(ctx, "err/b.pdf"); err == nil {
		t.Fatalf("expected error on 500 delete without fallback")
	}
}
