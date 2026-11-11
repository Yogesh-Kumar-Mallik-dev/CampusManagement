package storage

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
)

// LocalStorage implements BlobStorage backed by the native OS filesystem
type LocalStorage struct {
	baseDir string
	mu      sync.RWMutex
}

// NewLocalStorage initializes storage in the specified filesystem directory
func NewLocalStorage(baseDir string) (*LocalStorage, error) {
	if baseDir == "" {
		home, err := os.UserHomeDir()
		if err == nil && home != "" {
			baseDir = filepath.Join(home, ".campus_management", "uploads")
		} else {
			baseDir = filepath.Join(os.TempDir(), "campus_uploads")
		}
	}

	cleanDir := filepath.Clean(baseDir)
	if err := os.MkdirAll(cleanDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to initialize local storage directory '%s': %w", cleanDir, err)
	}

	return &LocalStorage{
		baseDir: cleanDir,
	}, nil
}

func (l *LocalStorage) Driver() string {
	return "local"
}

func (l *LocalStorage) BaseDir() string {
	return l.baseDir
}

func (l *LocalStorage) resolvePath(key string) string {
	cleanKey := filepath.Clean(strings.TrimPrefix(key, "/"))
	return filepath.Join(l.baseDir, cleanKey)
}

func (l *LocalStorage) Upload(ctx context.Context, key string, data []byte, contentType string) (string, error) {
	l.mu.Lock()
	defer l.mu.Unlock()

	targetPath := l.resolvePath(key)
	dir := filepath.Dir(targetPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return "", fmt.Errorf("failed to create target folder '%s': %w", dir, err)
	}

	// Write atomically using a temporary file
	tmpPath := fmt.Sprintf("%s.tmp.%d", targetPath, os.Getpid())
	if err := os.WriteFile(tmpPath, data, 0644); err != nil {
		return "", fmt.Errorf("failed to write file '%s': %w", tmpPath, err)
	}

	if err := os.Rename(tmpPath, targetPath); err != nil {
		_ = os.Remove(tmpPath)
		return "", fmt.Errorf("failed to commit file '%s': %w", targetPath, err)
	}

	return l.URL(key), nil
}

func (l *LocalStorage) Download(ctx context.Context, key string) ([]byte, string, error) {
	l.mu.RLock()
	defer l.mu.RUnlock()

	targetPath := l.resolvePath(key)
	data, err := os.ReadFile(targetPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, "", fmt.Errorf("file not found: %s", key)
		}
		return nil, "", fmt.Errorf("failed to read file '%s': %w", targetPath, err)
	}

	contentType := "application/octet-stream"
	if strings.HasSuffix(strings.ToLower(key), ".pdf") {
		contentType = "application/pdf"
	}

	return data, contentType, nil
}

func (l *LocalStorage) Delete(ctx context.Context, key string) error {
	l.mu.Lock()
	defer l.mu.Unlock()

	targetPath := l.resolvePath(key)
	if err := os.Remove(targetPath); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("failed to delete file '%s': %w", targetPath, err)
	}
	return nil
}

func (l *LocalStorage) URL(key string) string {
	cleanKey := strings.TrimPrefix(key, "/")
	return fmt.Sprintf("/api/v1/uploads?id=%s", cleanKey)
}
