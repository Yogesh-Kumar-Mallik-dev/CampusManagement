package handler

import (
	"campus/backend/internal/model"
	"campus/backend/internal/service"
	"encoding/json"
	"net/http"
	"strings"
)

type ComplaintHandler struct {
	service *service.ComplaintService
}

func NewComplaintHandler(s *service.ComplaintService) *ComplaintHandler {
	return &ComplaintHandler{service: s}
}

// HandleComplaints handles GET (list) and POST (create).
func (h *ComplaintHandler) HandleComplaints(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	switch r.Method {
	case http.MethodGet:
		category := r.URL.Query().Get("category")
		status := r.URL.Query().Get("status")
		submittedBy := r.URL.Query().Get("submitted_by")
		viewerID := r.URL.Query().Get("viewer_id")
		allowedCatsParam := r.URL.Query().Get("allowed_categories")

		var allowedCats []string
		if allowedCatsParam != "" {
			for _, c := range strings.Split(allowedCatsParam, ",") {
				trimmed := strings.TrimSpace(c)
				if trimmed != "" {
					allowedCats = append(allowedCats, trimmed)
				}
			}
		}

		complaints := h.service.ListComplaints(category, status, submittedBy, viewerID, allowedCats)
		json.NewEncoder(w).Encode(complaints)

	case http.MethodPost:
		var c model.Complaint
		if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
			http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
			return
		}

		created, err := h.service.CreateComplaint(c)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(created)

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// HandleComplaintStatus handles PUT (update status & resolution remarks).
func (h *ComplaintHandler) HandleComplaintStatus(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if r.Method != http.MethodPut {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		ComplaintID string `json:"complaint_id"`
		Status      string `json:"status"`
		Remarks     string `json:"remarks"`
		ResolvedBy  string `json:"resolved_by"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
		return
	}

	if strings.TrimSpace(req.ComplaintID) == "" {
		http.Error(w, "complaint_id is required", http.StatusBadRequest)
		return
	}

	updated, err := h.service.UpdateComplaintStatus(req.ComplaintID, req.Status, req.Remarks, req.ResolvedBy)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	json.NewEncoder(w).Encode(updated)
}
