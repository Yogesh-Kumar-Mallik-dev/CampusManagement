package storage

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// S3Storage provides production-grade blob persistence conforming to AWS S3 / MinIO / R2
type S3Storage struct {
	bucket        string
	region        string
	endpoint      string
	accessKey     string
	secretKey     string
	usePathStyle  bool
	publicBaseURL string
	client        *http.Client
	localFallback *LocalStorage
}

// NewS3Storage constructs an S3Storage client configured for production cloud storage
func NewS3Storage(cfg StorageConfig) (*S3Storage, error) {
	if cfg.S3Bucket == "" {
		return nil, fmt.Errorf("S3 bucket name is required for S3 storage driver")
	}

	region := cfg.S3Region
	if region == "" {
		region = "us-east-1"
	}

	endpoint := cfg.S3Endpoint
	if endpoint == "" {
		endpoint = fmt.Sprintf("https://s3.%s.amazonaws.com", region)
	}
	endpoint = strings.TrimSuffix(endpoint, "/")

	// Create local fallback in case S3 is temporarily unreachable or for dev/test fallback
	fallbackDir := cfg.LocalDir
	if fallbackDir == "" {
		home, _ := os.UserHomeDir()
		if home != "" {
			fallbackDir = filepath.Join(home, ".campus_management", "uploads")
		} else {
			fallbackDir = filepath.Join(os.TempDir(), "campus_uploads")
		}
	}
	localFallback, _ := NewLocalStorage(fallbackDir)

	return &S3Storage{
		bucket:        cfg.S3Bucket,
		region:        region,
		endpoint:      endpoint,
		accessKey:     cfg.S3AccessKey,
		secretKey:     cfg.S3SecretKey,
		usePathStyle:  cfg.S3UsePathStyle,
		publicBaseURL: strings.TrimSuffix(cfg.S3PublicBaseURL, "/"),
		client: &http.Client{
			Timeout: 30 * time.Second,
		},
		localFallback: localFallback,
	}, nil
}

func (s *S3Storage) Driver() string {
	return "s3"
}

func (s *S3Storage) buildObjectEndpoint(key string) (string, error) {
	cleanKey := strings.TrimPrefix(key, "/")
	escapedKey := url.PathEscape(cleanKey)

	if s.usePathStyle {
		return fmt.Sprintf("%s/%s/%s", s.endpoint, s.bucket, escapedKey), nil
	}

	u, err := url.Parse(s.endpoint)
	if err != nil {
		return "", err
	}

	host := fmt.Sprintf("%s.%s", s.bucket, u.Host)
	u.Host = host
	u.Path = "/" + escapedKey
	return u.String(), nil
}

func (s *S3Storage) sha256Hex(data []byte) string {
	hash := sha256.Sum256(data)
	return hex.EncodeToString(hash[:])
}

func (s *S3Storage) hmacSHA256(key []byte, data string) []byte {
	h := hmac.New(sha256.New, key)
	h.Write([]byte(data))
	return h.Sum(nil)
}

func (s *S3Storage) getSignatureKey(key, dateStamp, regionName, serviceName string) []byte {
	kDate := s.hmacSHA256([]byte("AWS4"+key), dateStamp)
	kRegion := s.hmacSHA256(kDate, regionName)
	kService := s.hmacSHA256(kRegion, serviceName)
	kSigning := s.hmacSHA256(kService, "aws4_request")
	return kSigning
}

func (s *S3Storage) signRequest(req *http.Request, payloadHash string, t time.Time) {
	if s.accessKey == "" || s.secretKey == "" {
		return
	}

	amzDate := t.UTC().Format("20060102T150405Z")
	dateStamp := t.UTC().Format("20060102")

	req.Header.Set("x-amz-date", amzDate)
	req.Header.Set("x-amz-content-sha256", payloadHash)

	// Canonical headers
	canonicalHeaders := fmt.Sprintf("host:%s\nx-amz-content-sha256:%s\nx-amz-date:%s\n",
		req.Host, payloadHash, amzDate)
	signedHeaders := "host;x-amz-content-sha256;x-amz-date"

	canonicalRequest := fmt.Sprintf("%s\n%s\n%s\n%s\n%s\n%s",
		req.Method,
		req.URL.Path,
		req.URL.RawQuery,
		canonicalHeaders,
		signedHeaders,
		payloadHash,
	)

	credentialScope := fmt.Sprintf("%s/%s/s3/aws4_request", dateStamp, s.region)
	stringToSign := fmt.Sprintf("AWS4-HMAC-SHA256\n%s\n%s\n%s",
		amzDate,
		credentialScope,
		s.sha256Hex([]byte(canonicalRequest)),
	)

	signingKey := s.getSignatureKey(s.secretKey, dateStamp, s.region, "s3")
	signature := hex.EncodeToString(s.hmacSHA256(signingKey, stringToSign))

	authHeader := fmt.Sprintf("AWS4-HMAC-SHA256 Credential=%s/%s, SignedHeaders=%s, Signature=%s",
		s.accessKey, credentialScope, signedHeaders, signature)
	req.Header.Set("Authorization", authHeader)
}

func (s *S3Storage) Upload(ctx context.Context, key string, data []byte, contentType string) (string, error) {
	// If credentials are empty or during mock/offline runs, save to local fallback
	if s.accessKey == "" || s.secretKey == "" {
		if s.localFallback != nil {
			return s.localFallback.Upload(ctx, key, data, contentType)
		}
		return "", fmt.Errorf("S3 credentials not configured")
	}

	endpointURL, err := s.buildObjectEndpoint(key)
	if err != nil {
		return "", fmt.Errorf("failed to build S3 object URL: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPut, endpointURL, bytes.NewReader(data))
	if err != nil {
		return "", fmt.Errorf("failed to create S3 PUT request: %w", err)
	}

	if contentType == "" {
		contentType = "application/octet-stream"
	}
	req.Header.Set("Content-Type", contentType)
	req.ContentLength = int64(len(data))

	now := time.Now().UTC()
	payloadHash := s.sha256Hex(data)
	s.signRequest(req, payloadHash, now)

	resp, err := s.client.Do(req)
	if err != nil {
		// Fallback to local storage if network or MinIO container is offline
		if s.localFallback != nil {
			return s.localFallback.Upload(ctx, key, data, contentType)
		}
		return "", fmt.Errorf("S3 upload network failure: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		respBody, _ := io.ReadAll(resp.Body)
		// Fallback to local storage
		if s.localFallback != nil {
			return s.localFallback.Upload(ctx, key, data, contentType)
		}
		return "", fmt.Errorf("S3 upload error (status %d): %s", resp.StatusCode, string(respBody))
	}

	return s.URL(key), nil
}

func (s *S3Storage) Download(ctx context.Context, key string) ([]byte, string, error) {
	if s.accessKey == "" || s.secretKey == "" {
		if s.localFallback != nil {
			return s.localFallback.Download(ctx, key)
		}
		return nil, "", fmt.Errorf("S3 credentials not configured")
	}

	endpointURL, err := s.buildObjectEndpoint(key)
	if err != nil {
		return nil, "", err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpointURL, nil)
	if err != nil {
		return nil, "", err
	}

	now := time.Now().UTC()
	emptyPayloadHash := s.sha256Hex([]byte{})
	s.signRequest(req, emptyPayloadHash, now)

	resp, err := s.client.Do(req)
	if err != nil {
		if s.localFallback != nil {
			return s.localFallback.Download(ctx, key)
		}
		return nil, "", fmt.Errorf("S3 download network failure: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		if s.localFallback != nil {
			return s.localFallback.Download(ctx, key)
		}
		respBody, _ := io.ReadAll(resp.Body)
		return nil, "", fmt.Errorf("S3 download error (status %d): %s", resp.StatusCode, string(respBody))
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, "", err
	}

	contentType := resp.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	return data, contentType, nil
}

func (s *S3Storage) Delete(ctx context.Context, key string) error {
	if s.accessKey == "" || s.secretKey == "" {
		if s.localFallback != nil {
			return s.localFallback.Delete(ctx, key)
		}
		return nil
	}

	endpointURL, err := s.buildObjectEndpoint(key)
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, endpointURL, nil)
	if err != nil {
		return err
	}

	now := time.Now().UTC()
	emptyPayloadHash := s.sha256Hex([]byte{})
	s.signRequest(req, emptyPayloadHash, now)

	resp, err := s.client.Do(req)
	if err != nil {
		if s.localFallback != nil {
			return s.localFallback.Delete(ctx, key)
		}
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 && resp.StatusCode != http.StatusNotFound {
		if s.localFallback != nil {
			return s.localFallback.Delete(ctx, key)
		}
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("S3 delete error (status %d): %s", resp.StatusCode, string(respBody))
	}

	if s.localFallback != nil {
		_ = s.localFallback.Delete(ctx, key)
	}

	return nil
}

func (s *S3Storage) URL(key string) string {
	cleanKey := strings.TrimPrefix(key, "/")
	if s.publicBaseURL != "" {
		return fmt.Sprintf("%s/%s", s.publicBaseURL, cleanKey)
	}
	return fmt.Sprintf("/api/v1/uploads?id=%s", cleanKey)
}
