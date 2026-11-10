package handler

import (
	"encoding/json"
	"net/http"
	"strconv"

	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

// SessionalHandler handles HTTP routes for AKTU sessional assessment, marks entry, and HOD audits
type SessionalHandler struct {
	svc service.SessionalServiceInterface
}

// NewSessionalHandler initializes a new SessionalHandler
func NewSessionalHandler(svc service.SessionalServiceInterface) *SessionalHandler {
	return &SessionalHandler{svc: svc}
}

// HandleRecords routes GET requests for student internal marks
func (h *SessionalHandler) HandleRecords(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	studentID := r.URL.Query().Get("student_id")
	subjectCode := r.URL.Query().Get("subject_code")
	semesterStr := r.URL.Query().Get("semester")
	semester := 0
	if semesterStr != "" {
		semester, _ = strconv.Atoi(semesterStr)
	}

	records, err := h.svc.GetRecords(r.Context(), studentID, subjectCode, semester)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(records)
}

// HandleMarks handles POST requests to update continuous marks
func (h *SessionalHandler) HandleMarks(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req model.UpdateMarksRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body: "+err.Error(), http.StatusBadRequest)
		return
	}

	updated, err := h.svc.RecordMarks(r.Context(), req)
	if err != nil {
		if err == service.ErrMarksAlreadyFrozen {
			http.Error(w, err.Error(), http.StatusConflict)
			return
		}
		if err == service.ErrAssessmentRecordNotFound {
			http.Error(w, err.Error(), http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(updated)
}

// HandleFreeze handles POST requests to finalize and freeze internal marks
func (h *SessionalHandler) HandleFreeze(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req model.FreezeInternalMarksRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body: "+err.Error(), http.StatusBadRequest)
		return
	}

	awardList, err := h.svc.FreezeMarks(r.Context(), req)
	if err != nil {
		if err == service.ErrAssessmentRecordNotFound {
			http.Error(w, err.Error(), http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(awardList)
}

// HandleSchedule routes GET requests for datesheet schedules
func (h *SessionalHandler) HandleSchedule(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	semesterStr := r.URL.Query().Get("semester")
	semester := 0
	if semesterStr != "" {
		semester, _ = strconv.Atoi(semesterStr)
	}
	examType := r.URL.Query().Get("exam_type")

	schedules, err := h.svc.GetSchedules(r.Context(), semester, examType)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(schedules)
}

// HandleSeating routes GET requests for exam hall desk allocations
func (h *SessionalHandler) HandleSeating(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	hallNumber := r.URL.Query().Get("hall_number")
	examType := r.URL.Query().Get("exam_type")

	seating, err := h.svc.GetSeatingLayout(r.Context(), hallNumber, examType)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(seating)
}

// HandleAwardList routes GET requests for aggregated award list reports
func (h *SessionalHandler) HandleAwardList(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	subjectCode := r.URL.Query().Get("subject_code")
	semesterStr := r.URL.Query().Get("semester")
	semester := 0
	if semesterStr != "" {
		semester, _ = strconv.Atoi(semesterStr)
	}

	awardList, err := h.svc.GetAwardList(r.Context(), subjectCode, semester)
	if err != nil {
		if err == service.ErrAssessmentRecordNotFound {
			http.Error(w, err.Error(), http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(awardList)
}
