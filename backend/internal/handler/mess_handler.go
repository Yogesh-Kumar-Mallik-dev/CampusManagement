package handler

import (
	"encoding/json"
	"net/http"

	"campus/backend/internal/service"
)

type MessHandler struct {
	messService *service.MessService
}

func NewMessHandler(svc *service.MessService) *MessHandler {
	return &MessHandler{messService: svc}
}

// HandleTimetable returns the weekly mess timetable (6 days x 3 meals + Sunday Brunch & Dinner).
// GET /api/v1/mess/timetable
func (h *MessHandler) HandleTimetable(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	if r.Method != http.MethodGet {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	timetable := h.messService.GetWeeklyTimetable()
	_ = json.NewEncoder(w).Encode(timetable)
}

// HandleRatings handles GET /api/v1/mess/ratings and POST /api/v1/mess/ratings
func (h *MessHandler) HandleRatings(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	switch r.Method {
	case http.MethodGet:
		mealID := r.URL.Query().Get("meal_id")
		ratingFilter := r.URL.Query().Get("rating")
		report := h.messService.GetRatingsReport(mealID, ratingFilter)
		_ = json.NewEncoder(w).Encode(report)

	case http.MethodPost:
		var req service.SubmitRatingRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error":"invalid request payload"}`, http.StatusBadRequest)
			return
		}

		record, err := h.messService.SubmitRating(req)
		if err != nil {
			http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
			return
		}

		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(record)

	default:
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
	}
}
