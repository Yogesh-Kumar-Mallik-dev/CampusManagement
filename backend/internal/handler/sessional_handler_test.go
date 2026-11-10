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

func setupTestSessionalHandler() *SessionalHandler {
	svc := service.NewSessionalService(nil)
	return NewSessionalHandler(svc)
}

func TestSessionalHandler_GetRecords(t *testing.T) {
	h := setupTestSessionalHandler()

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sessional/records?student_id=usr-harish_2025_l_btech_1", nil)
	w := httptest.NewRecorder()
	h.HandleRecords(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d: %s", w.Code, w.Body.String())
	}

	var records []model.InternalAssessmentRecord
	if err := json.NewDecoder(w.Body).Decode(&records); err != nil {
		t.Fatalf("failed to decode records: %v", err)
	}

	if len(records) != 4 {
		t.Errorf("expected 4 records for Harish Kumar, got %d", len(records))
	}
}

func TestSessionalHandler_UpdateMarks(t *testing.T) {
	h := setupTestSessionalHandler()

	ct1 := 28.0
	payload, _ := json.Marshal(model.UpdateMarksRequest{
		SubjectCode: "CS301",
		StudentID:   "usr-harish_2025_l_btech_1",
		CT1Score:    &ct1,
		EnteredBy:   "prof_neha_sharma",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/sessional/marks", bytes.NewReader(payload))
	w := httptest.NewRecorder()
	h.HandleMarks(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d: %s", w.Code, w.Body.String())
	}

	var updated model.InternalAssessmentRecord
	json.NewDecoder(w.Body).Decode(&updated)
	if updated.CT1Score != 28.0 {
		t.Errorf("expected CT1 28.0, got %.1f", updated.CT1Score)
	}
}

func TestSessionalHandler_FreezeAndAwardList(t *testing.T) {
	h := setupTestSessionalHandler()

	freezePayload, _ := json.Marshal(model.FreezeInternalMarksRequest{
		SubjectCode: "CS301",
		Semester:    5,
		FrozenBy:    "dr_arun_kumar",
		Remarks:     "Approved by HOD",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/sessional/freeze", bytes.NewReader(freezePayload))
	w := httptest.NewRecorder()
	h.HandleFreeze(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d: %s", w.Code, w.Body.String())
	}

	var award model.AKTUInternalAwardList
	json.NewDecoder(w.Body).Decode(&award)
	if !award.IsFrozen || award.DigitalSignature == "" {
		t.Errorf("expected frozen award with signature")
	}

	// Verify award list endpoint
	getReq := httptest.NewRequest(http.MethodGet, "/api/v1/sessional/award-list?subject_code=CS301&semester=5", nil)
	getW := httptest.NewRecorder()
	h.HandleAwardList(getW, getReq)

	if getW.Code != http.StatusOK {
		t.Fatalf("expected 200 OK from award list, got %d", getW.Code)
	}
}

func TestSessionalHandler_ScheduleAndSeating(t *testing.T) {
	h := setupTestSessionalHandler()

	// 1. Schedule
	req1 := httptest.NewRequest(http.MethodGet, "/api/v1/sessional/schedule?semester=5&exam_type=CT-1", nil)
	w1 := httptest.NewRecorder()
	h.HandleSchedule(w1, req1)
	if w1.Code != http.StatusOK {
		t.Fatalf("expected 200 OK from schedule, got %d", w1.Code)
	}

	// 2. Seating
	req2 := httptest.NewRequest(http.MethodGet, "/api/v1/sessional/seating?hall_number=LT-101", nil)
	w2 := httptest.NewRecorder()
	h.HandleSeating(w2, req2)
	if w2.Code != http.StatusOK {
		t.Fatalf("expected 200 OK from seating, got %d", w2.Code)
	}
}
