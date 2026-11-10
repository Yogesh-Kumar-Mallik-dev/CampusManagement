package handler

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

func TestDigiLockerHandlerEndpoints(t *testing.T) {
	mockProfiles := make(map[string]model.StudentProfile)
	provider := func(id string) (*model.StudentProfile, bool) {
		sp, ok := mockProfiles[id]
		return &sp, ok
	}
	updater := func(sp model.StudentProfile) {
		mockProfiles[sp.UserID] = sp
	}

	digiSvc := service.NewDigiLockerService(service.DefaultDigiLockerConfig(), provider, updater)
	h := NewDigiLockerHandler(digiSvc)

	// 1. GET /api/v1/digilocker/auth-url without student_id (400)
	req := httptest.NewRequest(http.MethodGet, "/api/v1/digilocker/auth-url", nil)
	rr := httptest.NewRecorder()
	h.GenerateAuthURL(rr, req)
	if rr.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for missing student_id, got %d", rr.Code)
	}

	// 2. GET /api/v1/digilocker/auth-url with valid student_id (200)
	req = httptest.NewRequest(http.MethodGet, "/api/v1/digilocker/auth-url?student_id=usr-harish_2025_l_btech_1", nil)
	rr = httptest.NewRecorder()
	h.GenerateAuthURL(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200 for auth-url, got %d", rr.Code)
	}
	var authResp model.DigiLockerAuthURLResponse
	if err := json.NewDecoder(rr.Body).Decode(&authResp); err != nil {
		t.Fatalf("failed to decode auth response: %v", err)
	}
	if authResp.AuthURL == "" || authResp.State == "" {
		t.Errorf("expected populated auth_url and state")
	}

	// 3. POST /api/v1/digilocker/exchange
	exchangeBody := model.DigiLockerExchangeRequest{
		Code:         "test_code_999",
		State:        authResp.State,
		CodeVerifier: authResp.CodeVerifier,
		StudentID:    "usr-harish_2025_l_btech_1",
	}
	payload, _ := json.Marshal(exchangeBody)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/digilocker/exchange", bytes.NewReader(payload))
	rr = httptest.NewRecorder()
	h.ExchangeToken(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200 for exchange, got %d: %s", rr.Code, rr.Body.String())
	}
	var profile model.StudentProfile
	if err := json.NewDecoder(rr.Body).Decode(&profile); err != nil {
		t.Fatalf("failed to decode student profile: %v", err)
	}
	if !profile.DigiLockerVerified || profile.ABCID != "8912-3456-7890" {
		t.Errorf("expected verified profile with ABCID, got verified=%v abc=%s", profile.DigiLockerVerified, profile.ABCID)
	}

	// 4. GET /api/v1/digilocker/status
	req = httptest.NewRequest(http.MethodGet, "/api/v1/digilocker/status?student_id=usr-harish_2025_l_btech_1", nil)
	rr = httptest.NewRecorder()
	h.GetStatus(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200 for status, got %d", rr.Code)
	}
	var status model.DigiLockerStatusResponse
	if err := json.NewDecoder(rr.Body).Decode(&status); err != nil {
		t.Fatalf("failed to decode status: %v", err)
	}
	if !status.IsConnected || status.DocumentsCount != 5 {
		t.Errorf("expected connected with 5 documents, got %v and %d", status.IsConnected, status.DocumentsCount)
	}

	// 5. POST /api/v1/digilocker/disconnect
	discBody := map[string]string{"student_id": "usr-harish_2025_l_btech_1"}
	discPayload, _ := json.Marshal(discBody)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/digilocker/disconnect", bytes.NewReader(discPayload))
	rr = httptest.NewRecorder()
	h.Disconnect(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200 for disconnect, got %d", rr.Code)
	}
	var discProfile model.StudentProfile
	if err := json.NewDecoder(rr.Body).Decode(&discProfile); err != nil {
		t.Fatalf("failed to decode disconnected profile: %v", err)
	}
	if discProfile.DigiLockerVerified {
		t.Errorf("expected disconnected profile to have DigiLockerVerified=false")
	}
}
