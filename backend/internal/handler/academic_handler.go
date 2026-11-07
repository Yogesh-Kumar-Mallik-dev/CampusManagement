package handler

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

type AcademicHandler struct {
	academicService *service.AcademicService
}

func NewAcademicHandler(svc *service.AcademicService) *AcademicHandler {
	return &AcademicHandler{academicService: svc}
}

// ----------------------------------------------------
// COURSES
// ----------------------------------------------------

func (h *AcademicHandler) HandleCourses(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		courses, err := h.academicService.ListCourses(r.Context())
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(courses)

	case http.MethodPost:
		var c model.Course
		if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
			http.Error(w, "Invalid payload", http.StatusBadRequest)
			return
		}
		created, err := h.academicService.CreateCourse(r.Context(), c)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(created)

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// ----------------------------------------------------
// TIMETABLE
// ----------------------------------------------------

func (h *AcademicHandler) HandleTimetable(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		scope := r.URL.Query().Get("scope")
		slots, err := h.academicService.GetTimetableForScope(r.Context(), scope)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(slots)

	case http.MethodPost:
		var slot model.TimetableSlot
		if err := json.NewDecoder(r.Body).Decode(&slot); err != nil {
			http.Error(w, "Invalid payload", http.StatusBadRequest)
			return
		}
		created, err := h.academicService.CreateTimetableSlot(r.Context(), slot)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(created)

	case http.MethodPut:
		var slot model.TimetableSlot
		if err := json.NewDecoder(r.Body).Decode(&slot); err != nil {
			http.Error(w, "Invalid payload", http.StatusBadRequest)
			return
		}
		updated, err := h.academicService.UpdateTimetableSlot(r.Context(), slot)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(updated)

	case http.MethodDelete:
		id := r.URL.Query().Get("id")
		if id == "" {
			http.Error(w, "Missing slot ID", http.StatusBadRequest)
			return
		}
		if err := h.academicService.DeleteTimetableSlot(r.Context(), id); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusNoContent)

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// ----------------------------------------------------
// ATTENDANCE
// ----------------------------------------------------

func (h *AcademicHandler) SyncAttendance(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	markedBy := r.Header.Get("X-User-ID")
	if markedBy == "" {
		markedBy = "system"
	}

	var batch model.OfflineAttendanceBatch
	if err := json.NewDecoder(r.Body).Decode(&batch); err != nil {
		http.Error(w, "Invalid payload", http.StatusBadRequest)
		return
	}

	saved, err := h.academicService.SyncAttendanceBatch(r.Context(), markedBy, batch)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"status":         "synced",
		"sessions_count": len(saved),
		"sessions":       saved,
	})
}

func (h *AcademicHandler) GetAttendanceSummary(w http.ResponseWriter, r *http.Request) {
	studentID := r.URL.Query().Get("student_id")
	if studentID == "" {
		http.Error(w, "student_id is required", http.StatusBadRequest)
		return
	}

	summary, err := h.academicService.GetStudentAttendanceSummary(r.Context(), studentID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(summary)
}

// ----------------------------------------------------
// OPTICAL DATA TRANSFER ATTENDANCE HANDLERS
// ----------------------------------------------------

func (h *AcademicHandler) StartOpticalSession(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var sess model.OpticalAttendanceSession
	if err := json.NewDecoder(r.Body).Decode(&sess); err != nil {
		http.Error(w, "Invalid payload: "+err.Error(), http.StatusBadRequest)
		return
	}

	started, err := h.academicService.StartOpticalSession(r.Context(), sess)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(started)
}

func (h *AcademicHandler) VerifyOpticalAttendance(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req model.OpticalVerificationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid payload: "+err.Error(), http.StatusBadRequest)
		return
	}

	resp, err := h.academicService.VerifyOpticalAttendance(r.Context(), req)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}

func (h *AcademicHandler) GetOpticalSessionRoster(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	sessionID := r.URL.Query().Get("session_id")
	if sessionID == "" {
		http.Error(w, "session_id is required", http.StatusBadRequest)
		return
	}

	roster, err := h.academicService.GetOpticalSessionRoster(r.Context(), sessionID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(roster)
}

func (h *AcademicHandler) EndOpticalSession(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var payload struct {
		SessionID string `json:"session_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil || payload.SessionID == "" {
		http.Error(w, "session_id required", http.StatusBadRequest)
		return
	}

	finalized, err := h.academicService.EndOpticalSession(r.Context(), payload.SessionID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"status":    "concluded",
		"session":   finalized,
		"timestamp": time.Now().UTC(),
	})
}

// ----------------------------------------------------
// NOTICES
// ----------------------------------------------------

func (h *AcademicHandler) HandleNotices(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		scopesRaw := r.URL.Query().Get("scopes")
		var scopes []string
		if scopesRaw != "" {
			scopes = strings.Split(scopesRaw, ",")
		}
		notices, err := h.academicService.GetTargetedNotices(r.Context(), scopes)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(notices)

	case http.MethodPost:
		var n model.Notice
		if err := json.NewDecoder(r.Body).Decode(&n); err != nil {
			http.Error(w, "Invalid payload", http.StatusBadRequest)
			return
		}
		created, err := h.academicService.PublishNotice(r.Context(), n)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(created)

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// ----------------------------------------------------
// DELTA SYNC
// ----------------------------------------------------

func (h *AcademicHandler) DeltaSync(w http.ResponseWriter, r *http.Request) {
	sinceStr := r.URL.Query().Get("since")
	var since time.Time
	if sinceStr != "" {
		parsed, err := time.Parse(time.RFC3339, sinceStr)
		if err == nil {
			since = parsed
		}
	}

	scopesRaw := r.URL.Query().Get("scopes")
	var scopes []string
	if scopesRaw != "" {
		scopes = strings.Split(scopesRaw, ",")
	}

	resp, err := h.academicService.GetDeltaSync(r.Context(), since, scopes)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}
