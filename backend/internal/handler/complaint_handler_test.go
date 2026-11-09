package handler

import (
	"bytes"
	"campus/backend/internal/model"
	"campus/backend/internal/service"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestComplaintHandlerEndpoints(t *testing.T) {
	svc := service.NewComplaintService()
	h := NewComplaintHandler(svc)

	// 1. Test GET /api/v1/complaints
	req := httptest.NewRequest(http.MethodGet, "/api/v1/complaints", nil)
	rr := httptest.NewRecorder()
	h.HandleComplaints(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200 OK, got: %d", rr.Code)
	}

	var list []model.Complaint
	if err := json.NewDecoder(rr.Body).Decode(&list); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if len(list) == 0 {
		t.Fatalf("expected seeded complaints, got 0")
	}

	// 2. Test POST /api/v1/complaints (valid anonymous hostel)
	body, _ := json.Marshal(model.Complaint{
		Title:         "Hostel water heater trip in B-wing",
		Description:   "Geyser circuit breaker tripping intermittently.",
		Category:      model.ComplaintCategoryHostel,
		Urgency:       model.ComplaintUrgencyMedium,
		IsAnonymous:   true,
		SubmittedBy:   "usr-student-test",
		SubmitterName: "Test Name",
	})
	postReq := httptest.NewRequest(http.MethodPost, "/api/v1/complaints", bytes.NewReader(body))
	postRr := httptest.NewRecorder()
	h.HandleComplaints(postRr, postReq)

	if postRr.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created, got: %d, body: %s", postRr.Code, postRr.Body.String())
	}

	var created model.Complaint
	json.NewDecoder(postRr.Body).Decode(&created)
	if created.SubmitterName != "Anonymous Reporter" {
		t.Fatalf("expected SubmitterName to be masked, got: %s", created.SubmitterName)
	}

	// 3. Test POST /api/v1/complaints (invalid anonymous student)
	invalidBody, _ := json.Marshal(model.Complaint{
		Title:       "Anonymous exam grievance",
		Description: "Should fail validation",
		Category:    model.ComplaintCategoryStudent,
		IsAnonymous: true,
		SubmittedBy: "usr-student-test",
	})
	badReq := httptest.NewRequest(http.MethodPost, "/api/v1/complaints", bytes.NewReader(invalidBody))
	badRr := httptest.NewRecorder()
	h.HandleComplaints(badRr, badReq)

	if badRr.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 Bad Request, got: %d", badRr.Code)
	}

	// 4. Test PUT /api/v1/complaints/status
	statusBody, _ := json.Marshal(map[string]string{
		"complaint_id": created.ID,
		"status":       "resolved",
		"remarks":      "Electrician replaced breaker coil.",
		"resolved_by":  "usr-warden-1",
	})
	putReq := httptest.NewRequest(http.MethodPut, "/api/v1/complaints/status", bytes.NewReader(statusBody))
	putRr := httptest.NewRecorder()
	h.HandleComplaintStatus(putRr, putReq)

	if putRr.Code != http.StatusOK {
		t.Fatalf("expected 200 OK, got: %d, body: %s", putRr.Code, putRr.Body.String())
	}
}
