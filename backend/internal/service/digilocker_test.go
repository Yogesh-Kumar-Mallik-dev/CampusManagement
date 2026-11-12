package service

import (
	"context"
	"strings"
	"testing"

	"campus/backend/internal/model"
)

func TestDigiLockerServiceFullLifecycle(t *testing.T) {
	ctx := context.Background()

	mockProfiles := make(map[string]model.StudentProfile)
	provider := func(id string) (*model.StudentProfile, bool) {
		sp, ok := mockProfiles[id]
		return &sp, ok
	}
	updater := func(sp model.StudentProfile) {
		mockProfiles[sp.UserID] = sp
	}

	svc := NewDigiLockerService(DefaultDigiLockerConfig(), provider, updater)

	// 1. Generate Auth URL
	authResp, err := svc.GenerateAuthURL(ctx, model.DigiLockerAuthURLRequest{
		StudentID: "usr-harish_2025_l_btech_1",
	})
	if err != nil {
		t.Fatalf("unexpected error generating auth url: %v", err)
	}
	if !strings.Contains(authResp.AuthURL, "client_id=campus_erp_demo_client") {
		t.Errorf("expected client_id in auth url, got %s", authResp.AuthURL)
	}
	if !strings.Contains(authResp.AuthURL, "code_challenge=") {
		t.Errorf("expected code_challenge in auth url, got %s", authResp.AuthURL)
	}
	if authResp.State == "" || authResp.CodeVerifier == "" {
		t.Errorf("expected non-empty state and code_verifier")
	}

	// 2. Exchange & Sync (Sandbox)
	profile, err := svc.ExchangeAndSync(ctx, model.DigiLockerExchangeRequest{
		Code:         "demo_auth_code_12345",
		State:        authResp.State,
		CodeVerifier: authResp.CodeVerifier,
		StudentID:    "usr-harish_2025_l_btech_1",
	})
	if err != nil {
		t.Fatalf("unexpected error exchanging code: %v", err)
	}
	if !profile.DigiLockerVerified {
		t.Errorf("expected DigiLockerVerified to be true")
	}
	if profile.ABCID != "8912-3456-7890" {
		t.Errorf("expected ABCID 8912-3456-7890, got %s", profile.ABCID)
	}
	if len(profile.VerifiedDocuments) != 5 {
		t.Fatalf("expected 5 verified documents, got %d", len(profile.VerifiedDocuments))
	}

	for _, doc := range profile.VerifiedDocuments {
		if !strings.HasPrefix(doc.VerificationHash, "sha256:") {
			t.Errorf("expected sha256 prefix on verification hash, got %s", doc.VerificationHash)
		}
		if !doc.IsVerified || doc.Status != "verified" {
			t.Errorf("expected document to be verified, got status=%s isVerified=%v", doc.Status, doc.IsVerified)
		}
	}

	// 3. Status check
	status, err := svc.GetStatus(ctx, "usr-harish_2025_l_btech_1")
	if err != nil {
		t.Fatalf("unexpected error getting status: %v", err)
	}
	if !status.IsConnected || status.DocumentsCount != 5 {
		t.Errorf("expected is_connected=true count=5, got connected=%v count=%d", status.IsConnected, status.DocumentsCount)
	}

	// 4. Disconnect
	discProfile, err := svc.Disconnect(ctx, "usr-harish_2025_l_btech_1")
	if err != nil {
		t.Fatalf("unexpected error disconnecting: %v", err)
	}
	if discProfile.DigiLockerVerified {
		t.Errorf("expected DigiLockerVerified to be false after disconnect")
	}
	if len(discProfile.VerifiedDocuments) != 0 {
		t.Errorf("expected 0 verified documents after disconnect, got %d", len(discProfile.VerifiedDocuments))
	}
}

func TestDigiLockerServiceValidations(t *testing.T) {
	ctx := context.Background()
	svc := NewDigiLockerService(DefaultDigiLockerConfig(), nil, nil)

	// Missing student ID in Auth URL
	_, err := svc.GenerateAuthURL(ctx, model.DigiLockerAuthURLRequest{StudentID: ""})
	if err == nil {
		t.Errorf("expected error on empty student_id")
	}

	// Missing code in Exchange
	_, err = svc.ExchangeAndSync(ctx, model.DigiLockerExchangeRequest{
		Code:      "",
		StudentID: "usr-harish_2025_l_btech_1",
	})
	if err == nil {
		t.Errorf("expected error on empty code")
	}

	// Missing student ID in Exchange
	_, err = svc.ExchangeAndSync(ctx, model.DigiLockerExchangeRequest{
		Code:      "code123",
		StudentID: "",
	})
	if err == nil {
		t.Errorf("expected error on empty student_id")
	}
}

func TestDigiLockerConfigFromEnv(t *testing.T) {
	// Test defaults
	defaultCfg := DefaultDigiLockerConfig()
	envCfg := DigiLockerConfigFromEnv()
	if envCfg.ClientID != defaultCfg.ClientID {
		t.Errorf("expected default client id %s, got %s", defaultCfg.ClientID, envCfg.ClientID)
	}

	// Test overridden env variables
	t.Setenv("DIGILOCKER_ENV", "production")
	t.Setenv("DIGILOCKER_CLIENT_ID", "custom_client_123")
	t.Setenv("DIGILOCKER_CLIENT_SECRET", "custom_secret_456")
	t.Setenv("DIGILOCKER_REDIRECT_URI", "https://custom.campus.edu/callback")
	t.Setenv("DIGILOCKER_AUTH_URL", "https://custom.oauth.in/authorize")
	t.Setenv("DIGILOCKER_TOKEN_URL", "https://custom.oauth.in/token")
	t.Setenv("DIGILOCKER_API_BASE_URL", "https://custom.api.in/v2")

	customCfg := DigiLockerConfigFromEnv()
	if customCfg.Environment != "production" {
		t.Errorf("expected production, got %s", customCfg.Environment)
	}
	if customCfg.ClientID != "custom_client_123" {
		t.Errorf("expected custom_client_123, got %s", customCfg.ClientID)
	}
	if customCfg.ClientSecret != "custom_secret_456" {
		t.Errorf("expected custom_secret_456, got %s", customCfg.ClientSecret)
	}
	if customCfg.RedirectURI != "https://custom.campus.edu/callback" {
		t.Errorf("expected custom redirect uri, got %s", customCfg.RedirectURI)
	}
	if customCfg.AuthURL != "https://custom.oauth.in/authorize" {
		t.Errorf("expected custom auth url, got %s", customCfg.AuthURL)
	}
	if customCfg.TokenURL != "https://custom.oauth.in/token" {
		t.Errorf("expected custom token url, got %s", customCfg.TokenURL)
	}
	if customCfg.APIBaseURL != "https://custom.api.in/v2" {
		t.Errorf("expected custom api base url, got %s", customCfg.APIBaseURL)
	}
}
