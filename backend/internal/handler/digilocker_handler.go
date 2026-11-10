package handler

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

// DigiLockerHandler exposes HTTP REST endpoints for Government DigiLocker & APAAR integration
type DigiLockerHandler struct {
	digiService service.DigiLockerServiceInterface
}

func NewDigiLockerHandler(digiService service.DigiLockerServiceInterface) *DigiLockerHandler {
	return &DigiLockerHandler{
		digiService: digiService,
	}
}

// GenerateAuthURL returns an OAuth 2.0 PKCE consent URL for a student
func (h *DigiLockerHandler) GenerateAuthURL(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	studentID := strings.TrimSpace(r.URL.Query().Get("student_id"))
	if studentID == "" {
		http.Error(w, "student_id query parameter is required", http.StatusBadRequest)
		return
	}
	redirectURI := strings.TrimSpace(r.URL.Query().Get("redirect_uri"))

	resp, err := h.digiService.GenerateAuthURL(r.Context(), model.DigiLockerAuthURLRequest{
		StudentID:   studentID,
		RedirectURI: redirectURI,
	})
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to generate auth url: %v", err), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}

// ExchangeToken exchanges authorization code for verified government credentials
func (h *DigiLockerHandler) ExchangeToken(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req model.DigiLockerExchangeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, fmt.Sprintf("Invalid JSON body: %v", err), http.StatusBadRequest)
		return
	}

	profile, err := h.digiService.ExchangeAndSync(r.Context(), req)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to exchange DigiLocker token: %v", err), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(profile)
}

// GetStatus returns the verified credentials status for a student
func (h *DigiLockerHandler) GetStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	studentID := strings.TrimSpace(r.URL.Query().Get("student_id"))
	if studentID == "" {
		http.Error(w, "student_id query parameter is required", http.StatusBadRequest)
		return
	}

	status, err := h.digiService.GetStatus(r.Context(), studentID)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to get DigiLocker status: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(status)
}

// Disconnect revokes DigiLocker link for a student
func (h *DigiLockerHandler) Disconnect(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		StudentID string `json:"student_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, fmt.Sprintf("Invalid JSON body: %v", err), http.StatusBadRequest)
		return
	}

	profile, err := h.digiService.Disconnect(r.Context(), req.StudentID)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to disconnect DigiLocker: %v", err), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(profile)
}
