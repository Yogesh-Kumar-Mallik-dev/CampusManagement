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

func TestAcademicHandlerEndpoints(t *testing.T) {
	svc := service.NewAcademicService(nil, nil, nil)
	h := NewAcademicHandler(svc)

	// 1. Create a Course via POST
	courseJSON := `{"code":"CS301","name":"Operating Systems","credits":4,"semester":3}`
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/academics/courses", bytes.NewBufferString(courseJSON))
	h.HandleCourses(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created for course creation, got %d: %s", rec.Code, rec.Body.String())
	}

	// 2. List Courses via GET
	recList := httptest.NewRecorder()
	reqList := httptest.NewRequest(http.MethodGet, "/api/v1/academics/courses", nil)
	h.HandleCourses(recList, reqList)

	var courses []model.Course
	_ = json.Unmarshal(recList.Body.Bytes(), &courses)
	if len(courses) != 1 || courses[0].Code != "CS301" {
		t.Fatalf("expected 1 course CS301, got %v", courses)
	}

	// 3. Timetable Creation & Scope Query
	slotJSON := `{"course_id":"` + courses[0].ID + `","scope_code":"sec:cse-3a","day_of_week":1,"start_time":"09:00","end_time":"10:00","room_number":"LH-101"}`
	recSlot := httptest.NewRecorder()
	reqSlot := httptest.NewRequest(http.MethodPost, "/api/v1/academics/timetable", bytes.NewBufferString(slotJSON))
	h.HandleTimetable(recSlot, reqSlot)

	if recSlot.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created for slot, got %d", recSlot.Code)
	}

	recGetSlot := httptest.NewRecorder()
	reqGetSlot := httptest.NewRequest(http.MethodGet, "/api/v1/academics/timetable?scope=sec:cse-3a", nil)
	h.HandleTimetable(recGetSlot, reqGetSlot)

	var slots []model.TimetableSlot
	_ = json.Unmarshal(recGetSlot.Body.Bytes(), &slots)
	if len(slots) != 1 || slots[0].RoomNumber != "LH-101" {
		t.Fatalf("expected 1 slot with LH-101, got %v", slots)
	}

	// 4. Offline Attendance Sync
	batchJSON := `{
		"sessions": [{
			"course_id": "` + courses[0].ID + `",
			"scope_code": "sec:cse-3a",
			"session_date": "2026-11-03",
			"topic": "Virtual Memory",
			"records": [{
				"student_id": "usr-harish_1",
				"status": "present"
			}]
		}]
	}`
	recSync := httptest.NewRecorder()
	reqSync := httptest.NewRequest(http.MethodPost, "/api/v1/attendance/sync", bytes.NewBufferString(batchJSON))
	reqSync.Header.Set("X-User-ID", "usr-priya_1")
	h.SyncAttendance(recSync, reqSync)

	if recSync.Code != http.StatusOK {
		t.Fatalf("expected 200 OK for attendance sync, got %d: %s", recSync.Code, recSync.Body.String())
	}

	// 5. Attendance Summary Check
	recSumm := httptest.NewRecorder()
	reqSumm := httptest.NewRequest(http.MethodGet, "/api/v1/attendance/summary?student_id=usr-harish_1", nil)
	h.GetAttendanceSummary(recSumm, reqSumm)

	var summaries []model.AttendanceSummary
	_ = json.Unmarshal(recSumm.Body.Bytes(), &summaries)
	if len(summaries) != 1 || summaries[0].Percentage != 100.0 {
		t.Fatalf("expected 100%% attendance summary, got %v", summaries)
	}

	// 6. Targeted Notice Publish & Retrieve
	noticeJSON := `{"title":"Midsem Announcement","content":"Exams next week","category":"exam","target_scope_code":"sec:cse-3a"}`
	recNot := httptest.NewRecorder()
	reqNot := httptest.NewRequest(http.MethodPost, "/api/v1/notices", bytes.NewBufferString(noticeJSON))
	h.HandleNotices(recNot, reqNot)

	if recNot.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created for notice, got %d", recNot.Code)
	}

	recGetNot := httptest.NewRecorder()
	reqGetNot := httptest.NewRequest(http.MethodGet, "/api/v1/notices?scopes=sec:cse-3a", nil)
	h.HandleNotices(recGetNot, reqGetNot)

	var notices []model.Notice
	_ = json.Unmarshal(recGetNot.Body.Bytes(), &notices)
	if len(notices) != 1 || notices[0].Title != "Midsem Announcement" {
		t.Fatalf("expected 1 notice, got %v", notices)
	}

	// 7. Delta Sync
	recDelta := httptest.NewRecorder()
	reqDelta := httptest.NewRequest(http.MethodGet, "/api/v1/sync?scopes=sec:cse-3a", nil)
	h.DeltaSync(recDelta, reqDelta)

	if recDelta.Code != http.StatusOK {
		t.Fatalf("expected 200 OK for delta sync, got %d", recDelta.Code)
	}

	var delta model.DeltaSyncResponse
	_ = json.Unmarshal(recDelta.Body.Bytes(), &delta)
	if len(delta.Courses) != 1 || len(delta.TimetableSlots) != 1 || len(delta.Notices) != 1 {
		t.Fatalf("delta response mismatch: %+v", delta)
	}
}
