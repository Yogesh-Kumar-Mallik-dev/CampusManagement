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
}
