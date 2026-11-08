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

func TestMessHandlerEndpoints(t *testing.T) {
	svc := service.NewMessService(nil, nil)
	h := NewMessHandler(svc)

	// 1. Test GET /api/v1/mess/timetable
	reqTimetable := httptest.NewRequest(http.MethodGet, "/api/v1/mess/timetable", nil)
	wTimetable := httptest.NewRecorder()
	h.HandleTimetable(wTimetable, reqTimetable)

	if wTimetable.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", wTimetable.Code)
	}

	var meals []model.MessMeal
	if err := json.NewDecoder(wTimetable.Body).Decode(&meals); err != nil {
		t.Fatalf("failed to decode timetable: %v", err)
	}
	if len(meals) != 20 {
		t.Errorf("expected 20 meals in weekly timetable, got %d", len(meals))
	}

	// 2. Test GET /api/v1/mess/ratings
	reqRatings := httptest.NewRequest(http.MethodGet, "/api/v1/mess/ratings", nil)
	wRatings := httptest.NewRecorder()
	h.HandleRatings(wRatings, reqRatings)

	if wRatings.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", wRatings.Code)
	}

	var report model.MessReportSummary
	if err := json.NewDecoder(wRatings.Body).Decode(&report); err != nil {
		t.Fatalf("failed to decode ratings report: %v", err)
	}
	if report.TotalRatings == 0 {
		t.Errorf("expected seeded ratings in report")
	}

	// 3. Test POST /api/v1/mess/ratings with Very Poor rating but EMPTY message -> MUST FAIL (Compulsory)
	badBody, _ := json.Marshal(service.SubmitRatingRequest{
		MealID:       "meal-sunday-brunch",
		UserID:       "u-test",
		UserName:     "Test Student",
		CampusHandle: "test_student",
		Rating:       model.RatingVeryPoor,
		Message:      "",
	})
	reqBad := httptest.NewRequest(http.MethodPost, "/api/v1/mess/ratings", bytes.NewReader(badBody))
	wBad := httptest.NewRecorder()
	h.HandleRatings(wBad, reqBad)

	if wBad.Code != http.StatusBadRequest {
		t.Errorf("expected status 400 for empty compulsory feedback message, got %d", wBad.Code)
	}

	// 4. Test POST /api/v1/mess/ratings with Very Poor rating and COMPULSORY message -> SUCCEEDS
	goodBody, _ := json.Marshal(service.SubmitRatingRequest{
		MealID:       "meal-sunday-brunch",
		UserID:       "u-test",
		UserName:     "Test Student",
		CampusHandle: "test_student",
		Rating:       model.RatingVeryPoor,
		Message:      "Food ran out 45 minutes before brunch ended.",
	})
	reqGood := httptest.NewRequest(http.MethodPost, "/api/v1/mess/ratings", bytes.NewReader(goodBody))
	wGood := httptest.NewRecorder()
	h.HandleRatings(wGood, reqGood)

	if wGood.Code != http.StatusCreated {
		t.Errorf("expected status 201 for valid rating submission, got %d", wGood.Code)
	}
}
