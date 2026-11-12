package service

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"campus/backend/internal/model"
)

// DigiLockerConfig holds configuration credentials for DigiLocker / MeriPehchan integration
type DigiLockerConfig struct {
	Environment  string // "sandbox" or "production"
	ClientID     string
	ClientSecret string
	RedirectURI  string
	AuthURL      string
	TokenURL     string
	APIBaseURL   string
}

// DefaultDigiLockerConfig provides default development / sandbox configuration
func DefaultDigiLockerConfig() DigiLockerConfig {
	return DigiLockerConfig{
		Environment:  "sandbox",
		ClientID:     "campus_erp_demo_client",
		ClientSecret: "campus_demo_secret",
		RedirectURI:  "https://erp.campus.edu/api/v1/digilocker/callback",
		AuthURL:      "https://digilocker.meripehchan.gov.in/public/oauth2/1/authorize",
		TokenURL:     "https://digilocker.meripehchan.gov.in/public/oauth2/1/token",
		APIBaseURL:   "https://api.digitallocker.gov.in/public/oauth2/2",
	}
}

type pkceSession struct {
	StudentID    string
	CodeVerifier string
	CreatedAt    time.Time
}

// DigiLockerService implements DigiLockerServiceInterface
type DigiLockerService struct {
	cfg             DigiLockerConfig
	profileProvider func(id string) (*model.StudentProfile, bool)
	profileUpdater  func(sp model.StudentProfile)
	httpClient      *http.Client

	mu       sync.RWMutex
	sessions map[string]pkceSession // Key: state -> pkceSession
}

func NewDigiLockerService(
	cfg DigiLockerConfig,
	profileProvider func(id string) (*model.StudentProfile, bool),
	profileUpdater func(sp model.StudentProfile),
) *DigiLockerService {
	if cfg.Environment == "" {
		cfg.Environment = "sandbox"
	}
	if cfg.AuthURL == "" {
		cfg.AuthURL = "https://digilocker.meripehchan.gov.in/public/oauth2/1/authorize"
	}
	if cfg.TokenURL == "" {
		cfg.TokenURL = "https://digilocker.meripehchan.gov.in/public/oauth2/1/token"
	}
	if cfg.APIBaseURL == "" {
		cfg.APIBaseURL = "https://api.digitallocker.gov.in/public/oauth2/2"
	}

	return &DigiLockerService{
		cfg:             cfg,
		profileProvider: profileProvider,
		profileUpdater:  profileUpdater,
		httpClient:      &http.Client{Timeout: 15 * time.Second},
		sessions:        make(map[string]pkceSession),
	}
}

// GenerateAuthURL creates a cryptographically secure OAuth 2.0 PKCE challenge and returns the consent URL
func (s *DigiLockerService) GenerateAuthURL(ctx context.Context, req model.DigiLockerAuthURLRequest) (*model.DigiLockerAuthURLResponse, error) {
	studentID := strings.TrimSpace(req.StudentID)
	if studentID == "" {
		return nil, errors.New("student_id is required")
	}

	// Generate 32 bytes cryptographically secure random state
	stateBytes := make([]byte, 24)
	if _, err := io.ReadFull(rand.Reader, stateBytes); err != nil {
		return nil, fmt.Errorf("failed to generate random state: %w", err)
	}
	state := hex.EncodeToString(stateBytes)

	// Generate 32 bytes cryptographically secure code_verifier
	verifierBytes := make([]byte, 32)
	if _, err := io.ReadFull(rand.Reader, verifierBytes); err != nil {
		return nil, fmt.Errorf("failed to generate code verifier: %w", err)
	}
	codeVerifier := base64.RawURLEncoding.EncodeToString(verifierBytes)

	// S256 Code Challenge: Base64URL-encode(SHA256(ASCII(code_verifier)))
	hash := sha256.Sum256([]byte(codeVerifier))
	codeChallenge := base64.RawURLEncoding.EncodeToString(hash[:])

	// Store session in memory
	s.mu.Lock()
	// Clean expired sessions older than 15 minutes
	cutoff := time.Now().Add(-15 * time.Minute)
	for k, sess := range s.sessions {
		if sess.CreatedAt.Before(cutoff) {
			delete(s.sessions, k)
		}
	}
	s.sessions[state] = pkceSession{
		StudentID:    studentID,
		CodeVerifier: codeVerifier,
		CreatedAt:    time.Now(),
	}
	s.mu.Unlock()

	redirectURI := s.cfg.RedirectURI
	if req.RedirectURI != "" {
		redirectURI = req.RedirectURI
	}

	// Build consent URL
	params := url.Values{}
	params.Set("response_type", "code")
	params.Set("client_id", s.cfg.ClientID)
	params.Set("redirect_uri", redirectURI)
	params.Set("state", state)
	params.Set("code_challenge", codeChallenge)
	params.Set("code_challenge_method", "S256")
	params.Set("scope", "files.issued.xml files.pull")

	authURL := fmt.Sprintf("%s?%s", s.cfg.AuthURL, params.Encode())

	return &model.DigiLockerAuthURLResponse{
		AuthURL:      authURL,
		State:        state,
		CodeVerifier: codeVerifier,
		Environment:  s.cfg.Environment,
	}, nil
}

// ExchangeAndSync exchanges the authorization code, pulls student credentials, computes SHA-256 digests, and updates profile
func (s *DigiLockerService) ExchangeAndSync(ctx context.Context, req model.DigiLockerExchangeRequest) (*model.StudentProfile, error) {
	code := strings.TrimSpace(req.Code)
	if code == "" {
		return nil, errors.New("authorization code is required")
	}
	studentID := strings.TrimSpace(req.StudentID)
	if studentID == "" {
		return nil, errors.New("student_id is required")
	}

	// Validate state if provided
	if req.State != "" {
		s.mu.RLock()
		sess, ok := s.sessions[req.State]
		s.mu.RUnlock()
		if ok {
			if sess.StudentID != "" && sess.StudentID != studentID {
				return nil, errors.New("state session student_id mismatch")
			}
			if req.CodeVerifier != "" && sess.CodeVerifier != req.CodeVerifier {
				return nil, errors.New("code_verifier does not match registered challenge")
			}
			s.mu.Lock()
			delete(s.sessions, req.State)
			s.mu.Unlock()
		}
	}

	now := time.Now().UTC()
	nowStr := now.Format("2006-01-02 15:04 IST")

	// If sandbox environment or demo credentials, simulate the verified government records with real cryptographic hashes
	if s.cfg.Environment == "sandbox" || s.cfg.ClientID == "campus_erp_demo_client" {
		verifiedDocs := []model.VerifiedDocument{
			{
				DocumentType:     "apaar_abc",
				DocumentTitle:    "APAAR / Academic Bank of Credits (ABC) ID",
				Issuer:           "National Academic Depository (NAD) / MeitY",
				DocRefMasked:     "8912-XXXX-7890",
				IssuedYear:       2023,
				IsVerified:       true,
				VerificationHash: computeCredentialHash("apaar:8912-3456-7890:nad:2023"),
				VerifiedAt:       nowStr,
				Status:           "verified",
			},
			{
				DocumentType:     "class_x",
				DocumentTitle:    "Secondary School Certificate (Class X)",
				Issuer:           "Central Board of Secondary Education (CBSE)",
				DocRefMasked:     "ROLL-12894104",
				IssuedYear:       2021,
				IsVerified:       true,
				VerificationHash: computeCredentialHash("cbse:class_x:12894104:2021"),
				VerifiedAt:       nowStr,
				Status:           "verified",
			},
			{
				DocumentType:     "class_xii",
				DocumentTitle:    "Senior School Certificate (Class XII - PCM)",
				Issuer:           "Central Board of Secondary Education (CBSE)",
				DocRefMasked:     "ROLL-61928401",
				IssuedYear:       2023,
				IsVerified:       true,
				VerificationHash: computeCredentialHash("cbse:class_xii:61928401:2023"),
				VerifiedAt:       nowStr,
				Status:           "verified",
			},
			{
				DocumentType:     "aadhaar_kyc",
				DocumentTitle:    "Aadhaar e-KYC Verification Record",
				Issuer:           "Unique Identification Authority of India (UIDAI)",
				DocRefMasked:     "XXXX-XXXX-4091",
				IssuedYear:       2023,
				IsVerified:       true,
				VerificationHash: computeCredentialHash("uidai:aadhaar:4091:kyc_verified"),
				VerifiedAt:       nowStr,
				Status:           "verified",
			},
			{
				DocumentType:     "domicile",
				DocumentTitle:    "State Domicile Certificate",
				Issuer:           "Revenue Department, Govt of Uttar Pradesh",
				DocRefMasked:     "UP/DOM/2021/88921",
				IssuedYear:       2021,
				IsVerified:       true,
				VerificationHash: computeCredentialHash("up_edistrict:domicile:88921:2021"),
				VerifiedAt:       nowStr,
				Status:           "verified",
			},
		}

		profile := model.StudentProfile{
			UserID:               studentID,
			AdmissionYear:        2025,
			EntryType:            "lateral",
			Program:              "btech",
			CurrentSemester:      5,
			BatchYear:            2027,
			ABCID:                "8912-3456-7890",
			DigiLockerVerified:   true,
			DigiLockerVerifiedAt: &now,
			VerifiedDocuments:    verifiedDocs,
		}

		if s.profileProvider != nil {
			if existing, ok := s.profileProvider(studentID); ok && existing != nil {
				profile = *existing
				profile.ABCID = "8912-3456-7890"
				profile.DigiLockerVerified = true
				profile.DigiLockerVerifiedAt = &now
				profile.VerifiedDocuments = verifiedDocs
				if profile.AcademicName == "" {
					profile.AcademicName = "HARISH KUMAR"
				}
				profile.AcademicNameVerified = true
				profile.AcademicNameSource = "digilocker_class_x"
			}
		}

		if s.profileUpdater != nil {
			s.profileUpdater(profile)
		}

		return &profile, nil
	}

	// Production Live Flow: POST to Token URL
	form := url.Values{}
	form.Set("code", code)
	form.Set("grant_type", "authorization_code")
	form.Set("client_id", s.cfg.ClientID)
	form.Set("client_secret", s.cfg.ClientSecret)
	form.Set("redirect_uri", s.cfg.RedirectURI)
	form.Set("code_verifier", req.CodeVerifier)

	tokenReq, err := http.NewRequestWithContext(ctx, http.MethodPost, s.cfg.TokenURL, strings.NewReader(form.Encode()))
	if err != nil {
		return nil, fmt.Errorf("failed to create token request: %w", err)
	}
	tokenReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	tokenResp, err := s.httpClient.Do(tokenReq)
	if err != nil {
		return nil, fmt.Errorf("failed to exchange code with DigiLocker: %w", err)
	}
	defer tokenResp.Body.Close()

	if tokenResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(tokenResp.Body)
		return nil, fmt.Errorf("digilocker token exchange failed (%d): %s", tokenResp.StatusCode, string(body))
	}

	var tok model.DigiLockerTokenResponse
	if err := json.NewDecoder(tokenResp.Body).Decode(&tok); err != nil {
		return nil, fmt.Errorf("failed to decode token response: %w", err)
	}

	// Query Issued Files API
	filesReq, err := http.NewRequestWithContext(ctx, http.MethodGet, s.cfg.APIBaseURL+"/xml/issued", nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create issued files request: %w", err)
	}
	filesReq.Header.Set("Authorization", "Bearer "+tok.AccessToken)

	filesResp, err := s.httpClient.Do(filesReq)
	if err != nil {
		return nil, fmt.Errorf("failed to query issued documents: %w", err)
	}
	defer filesResp.Body.Close()

	var issuedDocs []model.VerifiedDocument
	if filesResp.StatusCode == http.StatusOK {
		var rawFiles []model.DigiLockerIssuedFile
		if err := json.NewDecoder(filesResp.Body).Decode(&rawFiles); err == nil {
			for _, f := range rawFiles {
				issuedDocs = append(issuedDocs, model.VerifiedDocument{
					DocumentType:     f.DocType,
					DocumentTitle:    f.Description,
					Issuer:           f.Issuer,
					DocRefMasked:     f.Name,
					IssuedYear:       time.Now().Year(),
					IsVerified:       true,
					VerificationHash: computeCredentialHash(f.URI + ":" + f.Name),
					VerifiedAt:       nowStr,
					Status:           "verified",
				})
			}
		}
	}

	profile := model.StudentProfile{
		UserID:               studentID,
		AdmissionYear:        2025,
		EntryType:            "regular",
		Program:              "btech",
		CurrentSemester:      5,
		BatchYear:            2027,
		ABCID:                tok.DigiLockerID,
		DigiLockerVerified:   true,
		DigiLockerVerifiedAt: &now,
		VerifiedDocuments:    issuedDocs,
	}

	if s.profileProvider != nil {
		if existing, ok := s.profileProvider(studentID); ok && existing != nil {
			profile = *existing
			profile.ABCID = tok.DigiLockerID
			profile.DigiLockerVerified = true
			profile.DigiLockerVerifiedAt = &now
			profile.VerifiedDocuments = issuedDocs
		}
	}

	if s.profileUpdater != nil {
		s.profileUpdater(profile)
	}

	return &profile, nil
}

// GetStatus checks whether a student has an active verified DigiLocker connection
func (s *DigiLockerService) GetStatus(ctx context.Context, studentID string) (*model.DigiLockerStatusResponse, error) {
	studentID = strings.TrimSpace(studentID)
	if studentID == "" {
		return nil, errors.New("student_id is required")
	}

	var sp *model.StudentProfile
	if s.profileProvider != nil {
		p, ok := s.profileProvider(studentID)
		if ok && p != nil {
			sp = p
		}
	}

	if sp == nil {
		return &model.DigiLockerStatusResponse{
			StudentID:       studentID,
			IsConnected:     false,
			DocumentsCount:  0,
			EnvironmentMode: s.cfg.Environment,
		}, nil
	}

	return &model.DigiLockerStatusResponse{
		StudentID:       studentID,
		IsConnected:     sp.DigiLockerVerified,
		ABCID:           sp.ABCID,
		VerifiedAt:      sp.DigiLockerVerifiedAt,
		DocumentsCount:  len(sp.VerifiedDocuments),
		Documents:       sp.VerifiedDocuments,
		EnvironmentMode: s.cfg.Environment,
	}, nil
}

// Disconnect revokes DigiLocker link and clears cached government credentials
func (s *DigiLockerService) Disconnect(ctx context.Context, studentID string) (*model.StudentProfile, error) {
	studentID = strings.TrimSpace(studentID)
	if studentID == "" {
		return nil, errors.New("student_id is required")
	}

	var profile model.StudentProfile
	if s.profileProvider != nil {
		if existing, ok := s.profileProvider(studentID); ok && existing != nil {
			profile = *existing
		}
	}
	profile.UserID = studentID
	profile.DigiLockerVerified = false
	profile.DigiLockerVerifiedAt = nil
	profile.ABCID = ""
	profile.VerifiedDocuments = nil

	if s.profileUpdater != nil {
		s.profileUpdater(profile)
	}

	return &profile, nil
}

func computeCredentialHash(input string) string {
	h := sha256.Sum256([]byte(input))
	return "sha256:" + hex.EncodeToString(h[:])
}
