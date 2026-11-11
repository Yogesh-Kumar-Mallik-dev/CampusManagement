package storage

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// BlobStorage defines the universal interface for binary asset and PDF storage
type BlobStorage interface {
	Upload(ctx context.Context, key string, data []byte, contentType string) (string, error)
	Download(ctx context.Context, key string) ([]byte, string, error)
	Delete(ctx context.Context, key string) error
	URL(key string) string
	Driver() string
}

// StorageConfig holds options for either local filesystem or S3 cloud storage
type StorageConfig struct {
	Driver          string // "local" or "s3"
	LocalDir        string // Base filesystem path for local storage
	S3Bucket        string // S3 bucket name
	S3Region        string // AWS region, e.g. "us-east-1", "ap-south-1"
	S3Endpoint      string // Custom endpoint for MinIO, Cloudflare R2, LocalStack
	S3AccessKey     string // AWS / S3 access key ID
	S3SecretKey     string // AWS / S3 secret access key
	S3UsePathStyle  bool   // Path-style addressing (recommended for MinIO/R2)
	S3PublicBaseURL string // Optional public CDN URL prefix
}

// NewStorage initializes a BlobStorage implementation based on config
func NewStorage(cfg StorageConfig) (BlobStorage, error) {
	driver := strings.ToLower(strings.TrimSpace(cfg.Driver))
	if driver == "s3" || (cfg.S3Bucket != "" && cfg.S3AccessKey != "") {
		return NewS3Storage(cfg)
	}

	// Default to native device filesystem
	localDir := cfg.LocalDir
	if localDir == "" {
		home, err := os.UserHomeDir()
		if err == nil && home != "" {
			localDir = filepath.Join(home, ".campus_management", "uploads")
		} else {
			localDir = filepath.Join(os.TempDir(), "campus_uploads")
		}
	}

	return NewLocalStorage(localDir)
}

// NewStorageFromEnv inspects environment variables to construct BlobStorage
func NewStorageFromEnv() (BlobStorage, error) {
	driver := os.Getenv("STORAGE_DRIVER")
	localDir := os.Getenv("STORAGE_LOCAL_DIR")
	if localDir == "" {
		localDir = os.Getenv("CAMPUS_UPLOADS_DIR")
	}

	bucket := os.Getenv("S3_BUCKET")
	if bucket == "" {
		bucket = os.Getenv("AWS_S3_BUCKET")
	}

	region := os.Getenv("S3_REGION")
	if region == "" {
		region = os.Getenv("AWS_REGION")
	}
	if region == "" {
		region = "us-east-1"
	}

	endpoint := os.Getenv("S3_ENDPOINT")
	accessKey := os.Getenv("S3_ACCESS_KEY")
	if accessKey == "" {
		accessKey = os.Getenv("AWS_ACCESS_KEY_ID")
	}

	secretKey := os.Getenv("S3_SECRET_KEY")
	if secretKey == "" {
		secretKey = os.Getenv("AWS_SECRET_ACCESS_KEY")
	}

	pathStyle := strings.ToLower(os.Getenv("S3_USE_PATH_STYLE")) != "false"
	publicURL := os.Getenv("S3_PUBLIC_BASE_URL")

	cfg := StorageConfig{
		Driver:          driver,
		LocalDir:        localDir,
		S3Bucket:        bucket,
		S3Region:        region,
		S3Endpoint:      endpoint,
		S3AccessKey:     accessKey,
		S3SecretKey:     secretKey,
		S3UsePathStyle:  pathStyle,
		S3PublicBaseURL: publicURL,
	}

	return NewStorage(cfg)
}

// FormatFileSize returns a human-readable representation of bytes
func FormatFileSize(bytes int64) string {
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
