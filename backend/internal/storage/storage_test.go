package storage

import (
	"context"
	"os"
	"path/filepath"
	"strings"
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
