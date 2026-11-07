package handler

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestAuthHandlerLogin(t *testing.T) {
	h := NewAuthHandler(nil)

	payload := LoginRequest{
		Identifier: "harish_2025_l_btech_1",
		Password:   "campus123",
	}
	body, _ := json.Marshal(payload)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(body))
	w := httptest.NewRecorder()

	h.Login(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Expected status 200, got %d", w.Code)
	}

	var resp LoginResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if resp.User.CampusHandle != "harish_2025_l_btech_1" {
		t.Errorf("Expected handle harish_2025_l_btech_1, got %s", resp.User.CampusHandle)
	}
	if len(resp.Scopes) == 0 {
		t.Errorf("Expected user scopes, got none")
	}

	// Test Admin Login
	adminPayload := LoginRequest{
		Identifier: "admin@campus.edu",
		Password:   "admin123",
	}
	adminBody, _ := json.Marshal(adminPayload)
	adminReq := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(adminBody))
	adminRec := httptest.NewRecorder()
	h.Login(adminRec, adminReq)

	if adminRec.Code != http.StatusOK {
		t.Fatalf("Expected admin login status 200, got %d", adminRec.Code)
	}
	var adminResp LoginResponse
	if err := json.NewDecoder(adminRec.Body).Decode(&adminResp); err != nil {
		t.Fatalf("Failed decoding admin response: %v", err)
	}
	if adminResp.User.CampusHandle != "campus_admin" {
		t.Errorf("Expected campus_admin handle, got %s", adminResp.User.CampusHandle)
	}
}
