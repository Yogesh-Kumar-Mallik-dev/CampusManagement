package handler

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

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

	// 8. Optical Attendance Data Transfer with Rapidly Changing QR Codes
	optStartJSON := `{
		"course_id": "` + courses[0].ID + `",
		"scope_code": "sec:cse-3a",
		"room_number": "LH-101",
		"marked_by_user_id": "usr-priya_1",
		"marked_by_name": "Dr. Priya Nair",
		"refresh_interval_ms": 1500
	}`
	recOptStart := httptest.NewRecorder()
	reqOptStart := httptest.NewRequest(http.MethodPost, "/api/v1/attendance/optical/start", bytes.NewBufferString(optStartJSON))
	h.StartOpticalSession(recOptStart, reqOptStart)

	if recOptStart.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created for optical session, got %d: %s", recOptStart.Code, recOptStart.Body.String())
	}

	var optSess model.OpticalAttendanceSession
	_ = json.Unmarshal(recOptStart.Body.Bytes(), &optSess)
	if optSess.ID == "" || optSess.SessionSecret == "" {
		t.Fatalf("invalid optical session response: %+v", optSess)
	}

	// Simulate student generating/scanning a valid live optical packet
	nowUnix := time.Now().Unix()
	seq := 12
	nonce := "abc12345"
	dataPayload := optSess.ID + ":12:" + string(bytes.TrimSpace([]byte(recDelta.Body.String()))) // placeholder for signature computation
	_ = dataPayload

	// Compute HMAC signature for test
	var expectedSig string
	{
		mac := hmac.New(sha256.New, []byte(optSess.SessionSecret))
		mac.Write([]byte(optSess.ID + ":12:" + bytesToString(nowUnix) + ":" + nonce))
		expectedSig = hex.EncodeToString(mac.Sum(nil))
	}

	verifyJSON := `{
		"session_id": "` + optSess.ID + `",
		"student_id": "usr-harish_2025_l_btech_1",
		"student_name": "Harish Kumar",
		"campus_handle": "harish_2025_l_btech_1",
		"sequence": ` + bytesToString(int64(seq)) + `,
		"timestamp": ` + bytesToString(nowUnix) + `,
		"nonce": "` + nonce + `",
		"signature": "` + expectedSig + `"
	}`
	recVerify := httptest.NewRecorder()
	reqVerify := httptest.NewRequest(http.MethodPost, "/api/v1/attendance/optical/verify", bytes.NewBufferString(verifyJSON))
	h.VerifyOpticalAttendance(recVerify, reqVerify)

	if recVerify.Code != http.StatusOK {
		t.Fatalf("expected 200 OK for optical verification, got %d: %s", recVerify.Code, recVerify.Body.String())
	}

	var vResp model.OpticalVerificationResponse
	_ = json.Unmarshal(recVerify.Body.Bytes(), &vResp)
	if !vResp.Verified || vResp.Handle != "harish_2025_l_btech_1" {
		t.Fatalf("invalid verification response: %+v", vResp)
	}

	// Verify duplicate scan rejection
	recDup := httptest.NewRecorder()
	reqDup := httptest.NewRequest(http.MethodPost, "/api/v1/attendance/optical/verify", bytes.NewBufferString(verifyJSON))
	h.VerifyOpticalAttendance(recDup, reqDup)
	if recDup.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 Bad Request on duplicate scan, got %d", recDup.Code)
	}

	// Verify roster
	recRoster := httptest.NewRecorder()
	reqRoster := httptest.NewRequest(http.MethodGet, "/api/v1/attendance/optical/roster?session_id="+optSess.ID, nil)
	h.GetOpticalSessionRoster(recRoster, reqRoster)
	if recRoster.Code != http.StatusOK {
		t.Fatalf("expected 200 OK on roster, got %d", recRoster.Code)
	}
	var roster []model.AttendanceRecord
	_ = json.Unmarshal(recRoster.Body.Bytes(), &roster)
	if len(roster) != 1 || roster[0].StudentID != "usr-harish_2025_l_btech_1" {
		t.Fatalf("expected 1 student in optical roster, got %v", roster)
	}
}

func bytesToString(n int64) string {
	return fmt.Sprintf("%d", n)
}

func TestTimetableConflictAndDayOffEndpoints(t *testing.T) {
	svc := service.NewAcademicService(nil, nil, nil)
	h := NewAcademicHandler(svc)

	// Seed slot
	slotJSON := `{"course_id":"c1","course_code":"CS301","scope_code":"sec:cse-3a","day_of_week":1,"start_time":"09:00","end_time":"10:00","room_number":"LH-101","slot_type":"lecture"}`
	recSlot := httptest.NewRecorder()
	reqSlot := httptest.NewRequest(http.MethodPost, "/api/v1/academics/timetable", bytes.NewBufferString(slotJSON))
	h.HandleTimetable(recSlot, reqSlot)
	if recSlot.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created, got %d", recSlot.Code)
	}

	// 1. Conflict Check: room conflict
	conflictPayload := `{"course_id":"c2","scope_code":"sec:cse-3b","day_of_week":1,"start_time":"09:00","end_time":"10:00","room_number":"LH-101","slot_type":"lecture"}`
	recConflict := httptest.NewRecorder()
	reqConflict := httptest.NewRequest(http.MethodPost, "/api/v1/academics/timetable/check-conflict", bytes.NewBufferString(conflictPayload))
	h.HandleTimetableCheckConflict(recConflict, reqConflict)

	if recConflict.Code != http.StatusOK {
		t.Fatalf("expected 200 OK for conflict check, got %d", recConflict.Code)
	}
	var conflictResp model.TimetableConflictResponse
	_ = json.Unmarshal(recConflict.Body.Bytes(), &conflictResp)
	if !conflictResp.HasConflict || len(conflictResp.Conflicts) == 0 || conflictResp.Conflicts[0].Type != "room" {
		t.Fatalf("expected room conflict, got %+v", conflictResp)
	}

	// 2. Day Off Endpoint
	dayOffPayload := `{"day_of_week":1,"scope_code":"sec:cse-3a","reason":"Founder's Day"}`
	recDayOff := httptest.NewRecorder()
	reqDayOff := httptest.NewRequest(http.MethodPost, "/api/v1/academics/timetable/day-off", bytes.NewBufferString(dayOffPayload))
	h.HandleTimetableDayOff(recDayOff, reqDayOff)
	if recDayOff.Code != http.StatusOK {
		t.Fatalf("expected 200 OK for day off, got %d", recDayOff.Code)
	}

	// 3. Restore Day Endpoint
	restorePayload := `{"day_of_week":1,"scope_code":"sec:cse-3a"}`
	recRestore := httptest.NewRecorder()
	reqRestore := httptest.NewRequest(http.MethodPost, "/api/v1/academics/timetable/restore-day", bytes.NewBufferString(restorePayload))
	h.HandleTimetableRestoreDay(recRestore, reqRestore)
	if recRestore.Code != http.StatusOK {
		t.Fatalf("expected 200 OK for restore day, got %d", recRestore.Code)
	}
}
