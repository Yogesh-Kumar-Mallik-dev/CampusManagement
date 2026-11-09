package handler

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"campus/backend/internal/model"
)

func TestComprehensiveAcademicHandler(t *testing.T) {
	acadH, deptH, userH, hostelH, messH, authH, complaintH := setupTestHandlers()
	_ = deptH
	_ = userH
	_ = hostelH
	_ = messH
	_ = authH
	_ = complaintH

	// Courses error cases
	reqCoursePut := httptest.NewRequest(http.MethodPut, "/api/v1/academics/courses", nil)
	rrCoursePut := httptest.NewRecorder()
	acadH.HandleCourses(rrCoursePut, reqCoursePut)
	if rrCoursePut.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 from courses PUT, got %d", rrCoursePut.Code)
	}

	reqCourseBad := httptest.NewRequest(http.MethodPost, "/api/v1/academics/courses", bytes.NewReader([]byte("{invalid")))
	rrCourseBad := httptest.NewRecorder()
	acadH.HandleCourses(rrCourseBad, reqCourseBad)
	if rrCourseBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from courses bad json, got %d", rrCourseBad.Code)
	}

	// Timetable CRUD and errors
	// GET scope
	reqGet := httptest.NewRequest(http.MethodGet, "/api/v1/academics/timetable?scope=sec:cse-3a", nil)
	rrGet := httptest.NewRecorder()
	acadH.HandleTimetable(rrGet, reqGet)
	if rrGet.Code != http.StatusOK {
		t.Fatalf("expected 200 from timetable GET, got %d", rrGet.Code)
	}

	// POST valid slot
	instrID := "usr-priya_2024_emp_1"
	newSlot := model.TimetableSlot{
		CourseID:       "crs-cs101",
		CourseCode:     "CS101",
		CourseName:     "Algorithms",
		InstructorID:   &instrID,
		InstructorName: "Dr. Priya Nair",
		DayOfWeek:      2,
		StartTime:      "10:00",
		EndTime:        "11:00",
		RoomNumber:     "LH-201",
		ScopeCode:      "sec:cse-3a",
		SlotType:       "lecture",
	}
	body, _ := json.Marshal(newSlot)
	reqPost := httptest.NewRequest(http.MethodPost, "/api/v1/academics/timetable", bytes.NewReader(body))
	rrPost := httptest.NewRecorder()
	acadH.HandleTimetable(rrPost, reqPost)
	if rrPost.Code != http.StatusCreated {
		t.Fatalf("expected 201 from timetable POST, got %d", rrPost.Code)
	}
	var createdSlot model.TimetableSlot
	_ = json.Unmarshal(rrPost.Body.Bytes(), &createdSlot)

	// POST invalid JSON
	reqPostBad := httptest.NewRequest(http.MethodPost, "/api/v1/academics/timetable", bytes.NewReader([]byte("{invalid")))
	rrPostBad := httptest.NewRecorder()
	acadH.HandleTimetable(rrPostBad, reqPostBad)
	if rrPostBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from timetable POST invalid JSON, got %d", rrPostBad.Code)
	}

	// PUT valid slot
	createdSlot.RoomNumber = "LH-202"
	putBody, _ := json.Marshal(createdSlot)
	reqPut := httptest.NewRequest(http.MethodPut, "/api/v1/academics/timetable", bytes.NewReader(putBody))
	rrPut := httptest.NewRecorder()
	acadH.HandleTimetable(rrPut, reqPut)
	if rrPut.Code != http.StatusOK {
		t.Fatalf("expected 200 from timetable PUT, got %d", rrPut.Code)
	}

	// PUT invalid JSON
	reqPutBad := httptest.NewRequest(http.MethodPut, "/api/v1/academics/timetable", bytes.NewReader([]byte("{invalid")))
	rrPutBad := httptest.NewRecorder()
	acadH.HandleTimetable(rrPutBad, reqPutBad)
	if rrPutBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from timetable PUT invalid JSON, got %d", rrPutBad.Code)
	}

	// DELETE missing ID
	reqDelBad := httptest.NewRequest(http.MethodDelete, "/api/v1/academics/timetable", nil)
	rrDelBad := httptest.NewRecorder()
	acadH.HandleTimetable(rrDelBad, reqDelBad)
	if rrDelBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from timetable DELETE missing ID, got %d", rrDelBad.Code)
	}

	// DELETE valid ID
	reqDel := httptest.NewRequest(http.MethodDelete, "/api/v1/academics/timetable?id="+createdSlot.ID, nil)
	rrDel := httptest.NewRecorder()
	acadH.HandleTimetable(rrDel, reqDel)
	if rrDel.Code != http.StatusNoContent {
		t.Fatalf("expected 204 from timetable DELETE, got %d", rrDel.Code)
	}

	// Method Not Allowed
	reqPatch := httptest.NewRequest(http.MethodPatch, "/api/v1/academics/timetable", nil)
	rrPatch := httptest.NewRecorder()
	acadH.HandleTimetable(rrPatch, reqPatch)
	if rrPatch.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 from timetable PATCH, got %d", rrPatch.Code)
	}

	// TimetableCheckConflict Method not allowed & invalid JSON
	reqConflictGet := httptest.NewRequest(http.MethodGet, "/api/v1/academics/timetable/check-conflict", nil)
	rrConflictGet := httptest.NewRecorder()
	acadH.HandleTimetableCheckConflict(rrConflictGet, reqConflictGet)
	if rrConflictGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 from conflict GET, got %d", rrConflictGet.Code)
	}

	reqConflictBad := httptest.NewRequest(http.MethodPost, "/api/v1/academics/timetable/check-conflict", bytes.NewReader([]byte("{invalid")))
	rrConflictBad := httptest.NewRecorder()
	acadH.HandleTimetableCheckConflict(rrConflictBad, reqConflictBad)
	if rrConflictBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from conflict invalid json, got %d", rrConflictBad.Code)
	}

	// DayOff & RestoreDay error paths
	reqDayOffGet := httptest.NewRequest(http.MethodGet, "/api/v1/academics/timetable/day-off", nil)
	rrDayOffGet := httptest.NewRecorder()
	acadH.HandleTimetableDayOff(rrDayOffGet, reqDayOffGet)
	if rrDayOffGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 from day-off GET, got %d", rrDayOffGet.Code)
	}

	reqDayOffBad := httptest.NewRequest(http.MethodPost, "/api/v1/academics/timetable/day-off", bytes.NewReader([]byte("{invalid")))
	rrDayOffBad := httptest.NewRecorder()
	acadH.HandleTimetableDayOff(rrDayOffBad, reqDayOffBad)
	if rrDayOffBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from day-off bad json, got %d", rrDayOffBad.Code)
	}

	reqRestoreGet := httptest.NewRequest(http.MethodGet, "/api/v1/academics/timetable/restore-day", nil)
	rrRestoreGet := httptest.NewRecorder()
	acadH.HandleTimetableRestoreDay(rrRestoreGet, reqRestoreGet)
	if rrRestoreGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 from restore-day GET, got %d", rrRestoreGet.Code)
	}

	reqRestoreBad := httptest.NewRequest(http.MethodPost, "/api/v1/academics/timetable/restore-day", bytes.NewReader([]byte("{invalid")))
	rrRestoreBad := httptest.NewRecorder()
	acadH.HandleTimetableRestoreDay(rrRestoreBad, reqRestoreBad)
	if rrRestoreBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from restore-day bad json, got %d", rrRestoreBad.Code)
	}

	// SyncAttendance error paths
	reqSyncGet := httptest.NewRequest(http.MethodGet, "/api/v1/attendance/sync", nil)
	rrSyncGet := httptest.NewRecorder()
	acadH.SyncAttendance(rrSyncGet, reqSyncGet)
	if rrSyncGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 from sync GET, got %d", rrSyncGet.Code)
	}

	reqSyncBad := httptest.NewRequest(http.MethodPost, "/api/v1/attendance/sync", bytes.NewReader([]byte("{invalid")))
	rrSyncBad := httptest.NewRecorder()
	acadH.SyncAttendance(rrSyncBad, reqSyncBad)
	if rrSyncBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from sync bad json, got %d", rrSyncBad.Code)
	}

	// AttendanceSummary
	reqSummNoUser := httptest.NewRequest(http.MethodGet, "/api/v1/attendance/summary", nil)
	rrSummNoUser := httptest.NewRecorder()
	acadH.GetAttendanceSummary(rrSummNoUser, reqSummNoUser)
	if rrSummNoUser.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from summary missing user_id, got %d", rrSummNoUser.Code)
	}

	reqSummValid := httptest.NewRequest(http.MethodGet, "/api/v1/attendance/summary?student_id=usr-harish_2025_l_btech_1", nil)
	rrSummValid := httptest.NewRecorder()
	acadH.GetAttendanceSummary(rrSummValid, reqSummValid)
	if rrSummValid.Code != http.StatusOK {
		t.Fatalf("expected 200 from summary valid student_id, got %d", rrSummValid.Code)
	}

	// Optical Session error paths
	reqOptStartGet := httptest.NewRequest(http.MethodGet, "/api/v1/attendance/optical/start", nil)
	rrOptStartGet := httptest.NewRecorder()
	acadH.StartOpticalSession(rrOptStartGet, reqOptStartGet)
	if rrOptStartGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 from optical start GET, got %d", rrOptStartGet.Code)
	}

	reqOptStartBad := httptest.NewRequest(http.MethodPost, "/api/v1/attendance/optical/start", bytes.NewReader([]byte("{invalid")))
	rrOptStartBad := httptest.NewRecorder()
	acadH.StartOpticalSession(rrOptStartBad, reqOptStartBad)
	if rrOptStartBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from optical start bad json, got %d", rrOptStartBad.Code)
	}

	reqOptVerGet := httptest.NewRequest(http.MethodGet, "/api/v1/attendance/optical/verify", nil)
	rrOptVerGet := httptest.NewRecorder()
	acadH.VerifyOpticalAttendance(rrOptVerGet, reqOptVerGet)
	if rrOptVerGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 from optical verify GET, got %d", rrOptVerGet.Code)
	}

	reqOptVerBad := httptest.NewRequest(http.MethodPost, "/api/v1/attendance/optical/verify", bytes.NewReader([]byte("{invalid")))
	rrOptVerBad := httptest.NewRecorder()
	acadH.VerifyOpticalAttendance(rrOptVerBad, reqOptVerBad)
	if rrOptVerBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from optical verify bad json, got %d", rrOptVerBad.Code)
	}

	reqOptRosterPost := httptest.NewRequest(http.MethodPost, "/api/v1/attendance/optical/roster", nil)
	rrOptRosterPost := httptest.NewRecorder()
	acadH.GetOpticalSessionRoster(rrOptRosterPost, reqOptRosterPost)
	if rrOptRosterPost.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 from optical roster POST, got %d", rrOptRosterPost.Code)
	}

	reqOptRosterNoID := httptest.NewRequest(http.MethodGet, "/api/v1/attendance/optical/roster", nil)
	rrOptRosterNoID := httptest.NewRecorder()
	acadH.GetOpticalSessionRoster(rrOptRosterNoID, reqOptRosterNoID)
	if rrOptRosterNoID.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from optical roster without session_id, got %d", rrOptRosterNoID.Code)
	}

	reqOptEndGet := httptest.NewRequest(http.MethodGet, "/api/v1/attendance/optical/end", nil)
	rrOptEndGet := httptest.NewRecorder()
	acadH.EndOpticalSession(rrOptEndGet, reqOptEndGet)
	if rrOptEndGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 from optical end GET, got %d", rrOptEndGet.Code)
	}

	reqOptEndBad := httptest.NewRequest(http.MethodPost, "/api/v1/attendance/optical/end", bytes.NewReader([]byte("{invalid")))
	rrOptEndBad := httptest.NewRecorder()
	acadH.EndOpticalSession(rrOptEndBad, reqOptEndBad)
	if rrOptEndBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from optical end bad json, got %d", rrOptEndBad.Code)
	}

	// Notices error paths
	reqNoticeDel := httptest.NewRequest(http.MethodDelete, "/api/v1/notices", nil)
	rrNoticeDel := httptest.NewRecorder()
	acadH.HandleNotices(rrNoticeDel, reqNoticeDel)
	if rrNoticeDel.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 from notices DELETE, got %d", rrNoticeDel.Code)
	}

	reqNoticeBad := httptest.NewRequest(http.MethodPost, "/api/v1/notices", bytes.NewReader([]byte("{invalid")))
	rrNoticeBad := httptest.NewRecorder()
	acadH.HandleNotices(rrNoticeBad, reqNoticeBad)
	if rrNoticeBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from notices bad json, got %d", rrNoticeBad.Code)
	}

	noticePayload := map[string]interface{}{
		"title":     "Comprehensive Exam Notice",
		"content":   "Examinations start next Monday.",
		"priority":  "high",
		"category":  "exam",
		"author":    "Dean Academics",
		"target":    "all",
		"posted_at": time.Now().Format(time.RFC3339),
	}
	noticeBody, _ := json.Marshal(noticePayload)
	reqNoticePost := httptest.NewRequest(http.MethodPost, "/api/v1/notices", bytes.NewReader(noticeBody))
	rrNoticePost := httptest.NewRecorder()
	acadH.HandleNotices(rrNoticePost, reqNoticePost)
	if rrNoticePost.Code != http.StatusCreated {
		t.Fatalf("expected 201 from notices POST, got %d", rrNoticePost.Code)
	}

	// DeltaSync
	reqDelta := httptest.NewRequest(http.MethodGet, "/api/v1/sync/delta", nil)
	rrDelta := httptest.NewRecorder()
	acadH.DeltaSync(rrDelta, reqDelta)
	if rrDelta.Code != http.StatusOK {
		t.Fatalf("expected 200 from delta sync initial, got %d", rrDelta.Code)
	}

	validSince := time.Now().Add(-1 * time.Hour).Format(time.RFC3339)
	reqDeltaValid := httptest.NewRequest(http.MethodGet, "/api/v1/sync/delta?since="+validSince+"&scopes=global,sec:cse-3a", nil)
	rrDeltaValid := httptest.NewRecorder()
	acadH.DeltaSync(rrDeltaValid, reqDeltaValid)
	if rrDeltaValid.Code != http.StatusOK {
		t.Fatalf("expected 200 from delta sync valid since, got %d", rrDeltaValid.Code)
	}
}

func TestComprehensiveHostelHandler(t *testing.T) {
	_, _, _, hostelH, _, _, _ := setupTestHandlers()

	// HandleRooms: invalid room number string
	reqBadRoom := httptest.NewRequest(http.MethodGet, "/api/v1/hostel/rooms?room=notanumber", nil)
	rrBadRoom := httptest.NewRecorder()
	hostelH.HandleRooms(rrBadRoom, reqBadRoom)
	if rrBadRoom.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for invalid room number, got %d", rrBadRoom.Code)
	}

	// HandleRooms: non-existent room
	reqMissingRoom := httptest.NewRequest(http.MethodGet, "/api/v1/hostel/rooms?room=9999", nil)
	rrMissingRoom := httptest.NewRecorder()
	hostelH.HandleRooms(rrMissingRoom, reqMissingRoom)
	if rrMissingRoom.Code != http.StatusNotFound {
		t.Fatalf("expected 404 for missing room, got %d", rrMissingRoom.Code)
	}

	// HandleRooms: floor filter
	reqFloor := httptest.NewRequest(http.MethodGet, "/api/v1/hostel/rooms?floor=1", nil)
	rrFloor := httptest.NewRecorder()
	hostelH.HandleRooms(rrFloor, reqFloor)
	if rrFloor.Code != http.StatusOK {
		t.Fatalf("expected 200 for floor query, got %d", rrFloor.Code)
	}

	// HandleRooms: invalid json POST & PUT
	reqPostBad := httptest.NewRequest(http.MethodPost, "/api/v1/hostel/rooms", bytes.NewReader([]byte("{invalid")))
	rrPostBad := httptest.NewRecorder()
	hostelH.HandleRooms(rrPostBad, reqPostBad)
	if rrPostBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for room post bad json, got %d", rrPostBad.Code)
	}

	reqPutBad := httptest.NewRequest(http.MethodPut, "/api/v1/hostel/rooms", bytes.NewReader([]byte("{invalid")))
	rrPutBad := httptest.NewRecorder()
	hostelH.HandleRooms(rrPutBad, reqPutBad)
	if rrPutBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for room put bad json, got %d", rrPutBad.Code)
	}

	// HandleRooms: Method Not Allowed
	reqDel := httptest.NewRequest(http.MethodDelete, "/api/v1/hostel/rooms", nil)
	rrDel := httptest.NewRecorder()
	hostelH.HandleRooms(rrDel, reqDel)
	if rrDel.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for rooms DELETE, got %d", rrDel.Code)
	}

	// HandleAssets: method not allowed GET
	reqAssetGet := httptest.NewRequest(http.MethodGet, "/api/v1/hostel/rooms/assets", nil)
	rrAssetGet := httptest.NewRecorder()
	hostelH.HandleAssets(rrAssetGet, reqAssetGet)
	if rrAssetGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for assets GET, got %d", rrAssetGet.Code)
	}

	// HandleAssets: bad json
	reqAssetPostBad := httptest.NewRequest(http.MethodPost, "/api/v1/hostel/rooms/assets", bytes.NewReader([]byte("{invalid")))
	rrAssetPostBad := httptest.NewRecorder()
	hostelH.HandleAssets(rrAssetPostBad, reqAssetPostBad)
	if rrAssetPostBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for assets post bad json, got %d", rrAssetPostBad.Code)
	}

	reqAssetPutBad := httptest.NewRequest(http.MethodPut, "/api/v1/hostel/rooms/assets", bytes.NewReader([]byte("{invalid")))
	rrAssetPutBad := httptest.NewRecorder()
	hostelH.HandleAssets(rrAssetPutBad, reqAssetPutBad)
	if rrAssetPutBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for assets put bad json, got %d", rrAssetPutBad.Code)
	}

	reqAssetDelBad := httptest.NewRequest(http.MethodDelete, "/api/v1/hostel/rooms/assets", bytes.NewReader([]byte("{invalid")))
	rrAssetDelBad := httptest.NewRecorder()
	hostelH.HandleAssets(rrAssetDelBad, reqAssetDelBad)
	if rrAssetDelBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for assets delete bad json, got %d", rrAssetDelBad.Code)
	}

	// HandleOccupants: method not allowed GET
	reqOccGet := httptest.NewRequest(http.MethodGet, "/api/v1/hostel/rooms/occupants", nil)
	rrOccGet := httptest.NewRecorder()
	hostelH.HandleOccupants(rrOccGet, reqOccGet)
	if rrOccGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for occupants GET, got %d", rrOccGet.Code)
	}

	// HandleOccupants: bad json
	reqOccPostBad := httptest.NewRequest(http.MethodPost, "/api/v1/hostel/rooms/occupants", bytes.NewReader([]byte("{invalid")))
	rrOccPostBad := httptest.NewRecorder()
	hostelH.HandleOccupants(rrOccPostBad, reqOccPostBad)
	if rrOccPostBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for occupants post bad json, got %d", rrOccPostBad.Code)
	}

	reqOccDelBad := httptest.NewRequest(http.MethodDelete, "/api/v1/hostel/rooms/occupants", bytes.NewReader([]byte("{invalid")))
	rrOccDelBad := httptest.NewRecorder()
	hostelH.HandleOccupants(rrOccDelBad, reqOccDelBad)
	if rrOccDelBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for occupants delete bad json, got %d", rrOccDelBad.Code)
	}
}

func TestComprehensiveUserHandler(t *testing.T) {
	_, _, userH, _, _, _, _ := setupTestHandlers()

	// CreateStudent errors
	reqStudGet := httptest.NewRequest(http.MethodGet, "/api/v1/users/students", nil)
	rrStudGet := httptest.NewRecorder()
	userH.CreateStudent(rrStudGet, reqStudGet)
	if rrStudGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for student GET, got %d", rrStudGet.Code)
	}

	reqStudBad := httptest.NewRequest(http.MethodPost, "/api/v1/users/students", bytes.NewReader([]byte("{invalid")))
	rrStudBad := httptest.NewRecorder()
	userH.CreateStudent(rrStudBad, reqStudBad)
	if rrStudBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for student bad json, got %d", rrStudBad.Code)
	}

	// CreateEmployee errors
	reqEmpGet := httptest.NewRequest(http.MethodGet, "/api/v1/users/employees", nil)
	rrEmpGet := httptest.NewRecorder()
	userH.CreateEmployee(rrEmpGet, reqEmpGet)
	if rrEmpGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for emp GET, got %d", rrEmpGet.Code)
	}

	reqEmpBad := httptest.NewRequest(http.MethodPost, "/api/v1/users/employees", bytes.NewReader([]byte("{invalid")))
	rrEmpBad := httptest.NewRecorder()
	userH.CreateEmployee(rrEmpBad, reqEmpBad)
	if rrEmpBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for emp bad json, got %d", rrEmpBad.Code)
	}

	// CreateContractor errors
	reqContGet := httptest.NewRequest(http.MethodGet, "/api/v1/users/contractors", nil)
	rrContGet := httptest.NewRecorder()
	userH.CreateContractor(rrContGet, reqContGet)
	if rrContGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for contractor GET, got %d", rrContGet.Code)
	}

	reqContBad := httptest.NewRequest(http.MethodPost, "/api/v1/users/contractors", bytes.NewReader([]byte("{invalid")))
	rrContBad := httptest.NewRecorder()
	userH.CreateContractor(rrContBad, reqContBad)
	if rrContBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for contractor bad json, got %d", rrContBad.Code)
	}

	// DiscontinueUser & ReactivateUser error paths
	reqDiscGet := httptest.NewRequest(http.MethodGet, "/api/v1/users/discontinue", nil)
	rrDiscGet := httptest.NewRecorder()
	userH.DiscontinueUser(rrDiscGet, reqDiscGet)
	if rrDiscGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 from discontinue GET, got %d", rrDiscGet.Code)
	}

	reqDiscBad := httptest.NewRequest(http.MethodPost, "/api/v1/users/discontinue", bytes.NewReader([]byte("{invalid")))
	rrDiscBad := httptest.NewRecorder()
	userH.DiscontinueUser(rrDiscBad, reqDiscBad)
	if rrDiscBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from discontinue bad json, got %d", rrDiscBad.Code)
	}

	reqDiscNoUser := httptest.NewRequest(http.MethodPost, "/api/v1/users/discontinue", bytes.NewReader([]byte(`{"user_id":""}`)))
	rrDiscNoUser := httptest.NewRecorder()
	userH.DiscontinueUser(rrDiscNoUser, reqDiscNoUser)
	if rrDiscNoUser.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from discontinue missing user_id, got %d", rrDiscNoUser.Code)
	}

	reqDiscUnknown := httptest.NewRequest(http.MethodPost, "/api/v1/users/discontinue", bytes.NewReader([]byte(`{"user_id":"usr-unknown-user-999"}`)))
	rrDiscUnknown := httptest.NewRecorder()
	userH.DiscontinueUser(rrDiscUnknown, reqDiscUnknown)
	if rrDiscUnknown.Code != http.StatusNotFound {
		t.Fatalf("expected 404 from discontinue unknown user, got %d", rrDiscUnknown.Code)
	}

	reqReactGet := httptest.NewRequest(http.MethodGet, "/api/v1/users/reactivate", nil)
	rrReactGet := httptest.NewRecorder()
	userH.ReactivateUser(rrReactGet, reqReactGet)
	if rrReactGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 from reactivate GET, got %d", rrReactGet.Code)
	}

	reqReactBad := httptest.NewRequest(http.MethodPost, "/api/v1/users/reactivate", bytes.NewReader([]byte("{invalid")))
	rrReactBad := httptest.NewRecorder()
	userH.ReactivateUser(rrReactBad, reqReactBad)
	if rrReactBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from reactivate bad json, got %d", rrReactBad.Code)
	}

	reqReactNoUser := httptest.NewRequest(http.MethodPost, "/api/v1/users/reactivate", bytes.NewReader([]byte(`{"user_id":""}`)))
	rrReactNoUser := httptest.NewRecorder()
	userH.ReactivateUser(rrReactNoUser, reqReactNoUser)
	if rrReactNoUser.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from reactivate missing user_id, got %d", rrReactNoUser.Code)
	}

	reqReactUnknown := httptest.NewRequest(http.MethodPost, "/api/v1/users/reactivate", bytes.NewReader([]byte(`{"user_id":"usr-unknown-user-999"}`)))
	rrReactUnknown := httptest.NewRecorder()
	userH.ReactivateUser(rrReactUnknown, reqReactUnknown)
	if rrReactUnknown.Code != http.StatusNotFound {
		t.Fatalf("expected 404 from reactivate unknown user, got %d", rrReactUnknown.Code)
	}

	// AssignRole errors
	reqAssignGet := httptest.NewRequest(http.MethodGet, "/api/v1/users/roles/assign", nil)
	rrAssignGet := httptest.NewRecorder()
	userH.AssignRole(rrAssignGet, reqAssignGet)
	if rrAssignGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 from assign role GET, got %d", rrAssignGet.Code)
	}

	reqAssignBad := httptest.NewRequest(http.MethodPost, "/api/v1/users/roles/assign", bytes.NewReader([]byte("{invalid")))
	rrAssignBad := httptest.NewRecorder()
	userH.AssignRole(rrAssignBad, reqAssignBad)
	if rrAssignBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from assign role bad json, got %d", rrAssignBad.Code)
	}

	// GetUserRoles errors
	reqRolesPost := httptest.NewRequest(http.MethodPost, "/api/v1/users/roles", nil)
	rrRolesPost := httptest.NewRecorder()
	userH.GetUserRoles(rrRolesPost, reqRolesPost)
	if rrRolesPost.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 from roles POST, got %d", rrRolesPost.Code)
	}

	reqRolesNoUser := httptest.NewRequest(http.MethodGet, "/api/v1/users/roles", nil)
	rrRolesNoUser := httptest.NewRecorder()
	userH.GetUserRoles(rrRolesNoUser, reqRolesNoUser)
	if rrRolesNoUser.Code != http.StatusNotFound {
		t.Fatalf("expected 404 from roles missing user_id, got %d", rrRolesNoUser.Code)
	}

	// GetUserProfile errors
	reqProfilePost := httptest.NewRequest(http.MethodPost, "/api/v1/users/profile", nil)
	rrProfilePost := httptest.NewRecorder()
	userH.GetUserProfile(rrProfilePost, reqProfilePost)
	if rrProfilePost.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 from profile POST, got %d", rrProfilePost.Code)
	}

	reqProfileNoUser := httptest.NewRequest(http.MethodGet, "/api/v1/users/profile", nil)
	rrProfileNoUser := httptest.NewRecorder()
	userH.GetUserProfile(rrProfileNoUser, reqProfileNoUser)
	if rrProfileNoUser.Code != http.StatusNotFound {
		t.Fatalf("expected 404 from profile missing user_id, got %d", rrProfileNoUser.Code)
	}
}

func TestComprehensiveDepartmentHandler(t *testing.T) {
	_, deptH, _, _, _, _, _ := setupTestHandlers()

	// HandleSubjects errors and methods
	reqSubjPut := httptest.NewRequest(http.MethodPut, "/api/v1/academics/subjects", nil)
	rrSubjPut := httptest.NewRecorder()
	deptH.HandleSubjects(rrSubjPut, reqSubjPut)
	if rrSubjPut.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for subjects PUT, got %d", rrSubjPut.Code)
	}

	reqSubjBad := httptest.NewRequest(http.MethodPost, "/api/v1/academics/subjects", bytes.NewReader([]byte("{invalid")))
	rrSubjBad := httptest.NewRecorder()
	deptH.HandleSubjects(rrSubjBad, reqSubjBad)
	if rrSubjBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for subjects bad json, got %d", rrSubjBad.Code)
	}

	reqSubjNoName := httptest.NewRequest(http.MethodPost, "/api/v1/academics/subjects", bytes.NewReader([]byte(`{"code":"CS999","name":""}`)))
	rrSubjNoName := httptest.NewRecorder()
	deptH.HandleSubjects(rrSubjNoName, reqSubjNoName)
	if rrSubjNoName.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for subject missing name, got %d", rrSubjNoName.Code)
	}

	reqSubjValid := httptest.NewRequest(http.MethodPost, "/api/v1/academics/subjects", bytes.NewReader([]byte(`{
		"code":"CS201",
		"name":"Data Structures",
		"department_id":"dept-cse",
		"semester_num":3,
		"credits":4,
		"is_lab":false
	}`)))
	rrSubjValid := httptest.NewRecorder()
	deptH.HandleSubjects(rrSubjValid, reqSubjValid)
	if rrSubjValid.Code != http.StatusCreated && rrSubjValid.Code != http.StatusOK {
		t.Fatalf("expected 201 for valid subject create, got %d", rrSubjValid.Code)
	}

	// HandleSubjectSyllabus errors and methods
	reqSylDel := httptest.NewRequest(http.MethodDelete, "/api/v1/academics/subjects/syllabus", nil)
	rrSylDel := httptest.NewRecorder()
	deptH.HandleSubjectSyllabus(rrSylDel, reqSylDel)
	if rrSylDel.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for syllabus DELETE, got %d", rrSylDel.Code)
	}

	reqSylNoSubj := httptest.NewRequest(http.MethodGet, "/api/v1/academics/subjects/syllabus", nil)
	rrSylNoSubj := httptest.NewRecorder()
	deptH.HandleSubjectSyllabus(rrSylNoSubj, reqSylNoSubj)
	if rrSylNoSubj.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for syllabus missing subject_id, got %d", rrSylNoSubj.Code)
	}

	reqSylBadPost := httptest.NewRequest(http.MethodPost, "/api/v1/academics/subjects/syllabus", bytes.NewReader([]byte("{invalid")))
	rrSylBadPost := httptest.NewRecorder()
	deptH.HandleSubjectSyllabus(rrSylBadPost, reqSylBadPost)
	if rrSylBadPost.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for syllabus bad json, got %d", rrSylBadPost.Code)
	}

	// HandleSemesters
	reqSemDel := httptest.NewRequest(http.MethodDelete, "/api/v1/academics/semesters", nil)
	rrSemDel := httptest.NewRecorder()
	deptH.HandleSemesters(rrSemDel, reqSemDel)
	if rrSemDel.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for semesters DELETE, got %d", rrSemDel.Code)
	}

	reqSemBadPost := httptest.NewRequest(http.MethodPost, "/api/v1/academics/semesters", bytes.NewReader([]byte("{invalid")))
	rrSemBadPost := httptest.NewRecorder()
	deptH.HandleSemesters(rrSemBadPost, reqSemBadPost)
	if rrSemBadPost.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for semesters POST, got %d", rrSemBadPost.Code)
	}

	reqSemGetList := httptest.NewRequest(http.MethodGet, "/api/v1/academics/semesters", nil)
	rrSemGetList := httptest.NewRecorder()
	deptH.HandleSemesters(rrSemGetList, reqSemGetList)
	if rrSemGetList.Code != http.StatusOK {
		t.Fatalf("expected 200 for semesters GET list, got %d", rrSemGetList.Code)
	}

	reqSemGetID := httptest.NewRequest(http.MethodGet, "/api/v1/academics/semesters?id=sem-1", nil)
	rrSemGetID := httptest.NewRecorder()
	deptH.HandleSemesters(rrSemGetID, reqSemGetID)
	if rrSemGetID.Code != http.StatusOK && rrSemGetID.Code != http.StatusNotFound {
		t.Fatalf("unexpected code for semesters GET by id: %d", rrSemGetID.Code)
	}

	// HandleSections
	reqSecDel := httptest.NewRequest(http.MethodDelete, "/api/v1/academics/sections", nil)
	rrSecDel := httptest.NewRecorder()
	deptH.HandleSections(rrSecDel, reqSecDel)
	if rrSecDel.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for sections DELETE, got %d", rrSecDel.Code)
	}

	reqSecBadPost := httptest.NewRequest(http.MethodPost, "/api/v1/academics/sections", bytes.NewReader([]byte("{invalid")))
	rrSecBadPost := httptest.NewRecorder()
	deptH.HandleSections(rrSecBadPost, reqSecBadPost)
	if rrSecBadPost.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for sections bad json, got %d", rrSecBadPost.Code)
	}

	reqSecFilter := httptest.NewRequest(http.MethodGet, "/api/v1/academics/sections?semester_id=sem-1&cohort_type=regular", nil)
	rrSecFilter := httptest.NewRecorder()
	deptH.HandleSections(rrSecFilter, reqSecFilter)
	if rrSecFilter.Code != http.StatusOK {
		t.Fatalf("expected 200 for sections with filter, got %d", rrSecFilter.Code)
	}

	// HandleAssignStudentToSection
	reqAssSecGet := httptest.NewRequest(http.MethodGet, "/api/v1/academics/sections/assign", nil)
	rrAssSecGet := httptest.NewRecorder()
	deptH.HandleAssignStudentToSection(rrAssSecGet, reqAssSecGet)
	if rrAssSecGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for assign student section GET, got %d", rrAssSecGet.Code)
	}

	reqAssSecBad := httptest.NewRequest(http.MethodPost, "/api/v1/academics/sections/assign", bytes.NewReader([]byte("{invalid")))
	rrAssSecBad := httptest.NewRecorder()
	deptH.HandleAssignStudentToSection(rrAssSecBad, reqAssSecBad)
	if rrAssSecBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for assign student section bad json, got %d", rrAssSecBad.Code)
	}

	// HandleTransferStudentSection
	reqTransGet := httptest.NewRequest(http.MethodGet, "/api/v1/academics/sections/transfer", nil)
	rrTransGet := httptest.NewRecorder()
	deptH.HandleTransferStudentSection(rrTransGet, reqTransGet)
	if rrTransGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for transfer student section GET, got %d", rrTransGet.Code)
	}

	reqTransBad := httptest.NewRequest(http.MethodPost, "/api/v1/academics/sections/transfer", bytes.NewReader([]byte("{invalid")))
	rrTransBad := httptest.NewRecorder()
	deptH.HandleTransferStudentSection(rrTransBad, reqTransBad)
	if rrTransBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for transfer student section bad json, got %d", rrTransBad.Code)
	}

	// HandleMergeSectionCohorts
	reqMergeGet := httptest.NewRequest(http.MethodGet, "/api/v1/academics/sections/merge", nil)
	rrMergeGet := httptest.NewRecorder()
	deptH.HandleMergeSectionCohorts(rrMergeGet, reqMergeGet)
	if rrMergeGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for merge cohorts GET, got %d", rrMergeGet.Code)
	}

	reqMergeBad := httptest.NewRequest(http.MethodPost, "/api/v1/academics/sections/merge", bytes.NewReader([]byte("{invalid")))
	rrMergeBad := httptest.NewRecorder()
	deptH.HandleMergeSectionCohorts(rrMergeBad, reqMergeBad)
	if rrMergeBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for merge cohorts bad json, got %d", rrMergeBad.Code)
	}

	// HandleLabBatches
	reqLabDel := httptest.NewRequest(http.MethodDelete, "/api/v1/academics/sections/batches", nil)
	rrLabDel := httptest.NewRecorder()
	deptH.HandleLabBatches(rrLabDel, reqLabDel)
	if rrLabDel.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for lab batches DELETE, got %d", rrLabDel.Code)
	}

	reqLabBadPost := httptest.NewRequest(http.MethodPost, "/api/v1/academics/sections/batches", bytes.NewReader([]byte("{invalid")))
	rrLabBadPost := httptest.NewRecorder()
	deptH.HandleLabBatches(rrLabBadPost, reqLabBadPost)
	if rrLabBadPost.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for lab batches bad json, got %d", rrLabBadPost.Code)
	}

	reqLabNoSec := httptest.NewRequest(http.MethodGet, "/api/v1/academics/sections/batches", nil)
	rrLabNoSec := httptest.NewRecorder()
	deptH.HandleLabBatches(rrLabNoSec, reqLabNoSec)
	if rrLabNoSec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for lab batches missing section_id, got %d", rrLabNoSec.Code)
	}

	reqLabMissingFields := httptest.NewRequest(http.MethodPost, "/api/v1/academics/sections/batches", bytes.NewReader([]byte(`{"section_id":""}`)))
	rrLabMissingFields := httptest.NewRecorder()
	deptH.HandleLabBatches(rrLabMissingFields, reqLabMissingFields)
	if rrLabMissingFields.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for lab batch missing fields, got %d", rrLabMissingFields.Code)
	}

	// HandleAutoPartitionBatches
	reqPartGet := httptest.NewRequest(http.MethodGet, "/api/v1/academics/sections/batches/auto-partition", nil)
	rrPartGet := httptest.NewRecorder()
	deptH.HandleAutoPartitionBatches(rrPartGet, reqPartGet)
	if rrPartGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for auto-partition GET, got %d", rrPartGet.Code)
	}

	reqPartBadPost := httptest.NewRequest(http.MethodPost, "/api/v1/academics/sections/batches/auto-partition", bytes.NewReader([]byte("{invalid")))
	rrPartBadPost := httptest.NewRecorder()
	deptH.HandleAutoPartitionBatches(rrPartBadPost, reqPartBadPost)
	if rrPartBadPost.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for auto-partition bad json, got %d", rrPartBadPost.Code)
	}

	// HandleAssignStudentBatch
	reqAssignBatchGet := httptest.NewRequest(http.MethodGet, "/api/v1/academics/sections/batches/assign", nil)
	rrAssignBatchGet := httptest.NewRecorder()
	deptH.HandleAssignStudentBatch(rrAssignBatchGet, reqAssignBatchGet)
	if rrAssignBatchGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for assign student batch GET, got %d", rrAssignBatchGet.Code)
	}

	reqAssignBatchBad := httptest.NewRequest(http.MethodPost, "/api/v1/academics/sections/batches/assign", bytes.NewReader([]byte("{invalid")))
	rrAssignBatchBad := httptest.NewRecorder()
	deptH.HandleAssignStudentBatch(rrAssignBatchBad, reqAssignBatchBad)
	if rrAssignBatchBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for assign student batch bad json, got %d", rrAssignBatchBad.Code)
	}

	// HandleFacultyAllocations
	reqAllocPatch := httptest.NewRequest(http.MethodPatch, "/api/v1/academics/faculty/allocations", nil)
	rrAllocPatch := httptest.NewRecorder()
	deptH.HandleFacultyAllocations(rrAllocPatch, reqAllocPatch)
	if rrAllocPatch.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for faculty allocations PATCH, got %d", rrAllocPatch.Code)
	}

	reqAllocDelNoID := httptest.NewRequest(http.MethodDelete, "/api/v1/academics/faculty/allocations", nil)
	rrAllocDelNoID := httptest.NewRecorder()
	deptH.HandleFacultyAllocations(rrAllocDelNoID, reqAllocDelNoID)
	if rrAllocDelNoID.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for faculty allocations DELETE missing id, got %d", rrAllocDelNoID.Code)
	}

	reqAllocBadPost := httptest.NewRequest(http.MethodPost, "/api/v1/academics/faculty/allocations", bytes.NewReader([]byte("{invalid")))
	rrAllocBadPost := httptest.NewRecorder()
	deptH.HandleFacultyAllocations(rrAllocBadPost, reqAllocBadPost)
	if rrAllocBadPost.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for faculty allocations bad json, got %d", rrAllocBadPost.Code)
	}

	reqAllocNoSec := httptest.NewRequest(http.MethodGet, "/api/v1/academics/faculty/allocations", nil)
	rrAllocNoSec := httptest.NewRecorder()
	deptH.HandleFacultyAllocations(rrAllocNoSec, reqAllocNoSec)
	if rrAllocNoSec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for allocations without section_id, got %d", rrAllocNoSec.Code)
	}

	reqAllocWithSec := httptest.NewRequest(http.MethodGet, "/api/v1/academics/faculty/allocations?section_id=sec-sem1-cse-a", nil)
	rrAllocWithSec := httptest.NewRecorder()
	deptH.HandleFacultyAllocations(rrAllocWithSec, reqAllocWithSec)
	if rrAllocWithSec.Code != http.StatusOK {
		t.Fatalf("expected 200 for allocations with section_id, got %d", rrAllocWithSec.Code)
	}

	// HandleFacultyWorkload
	reqWorkloadPost := httptest.NewRequest(http.MethodPost, "/api/v1/academics/faculty/workload", nil)
	rrWorkloadPost := httptest.NewRecorder()
	deptH.HandleFacultyWorkload(rrWorkloadPost, reqWorkloadPost)
	if rrWorkloadPost.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for faculty workload POST, got %d", rrWorkloadPost.Code)
	}

	reqWorkloadAll := httptest.NewRequest(http.MethodGet, "/api/v1/academics/faculty/workload", nil)
	rrWorkloadAll := httptest.NewRecorder()
	deptH.HandleFacultyWorkload(rrWorkloadAll, reqWorkloadAll)
	if rrWorkloadAll.Code != http.StatusOK {
		t.Fatalf("expected 200 for all faculty workloads, got %d", rrWorkloadAll.Code)
	}

	reqWorkloadMissing := httptest.NewRequest(http.MethodGet, "/api/v1/academics/faculty/workload?teacher_id=non-existent-faculty", nil)
	rrWorkloadMissing := httptest.NewRecorder()
	deptH.HandleFacultyWorkload(rrWorkloadMissing, reqWorkloadMissing)
	if rrWorkloadMissing.Code != http.StatusNotFound && rrWorkloadMissing.Code != http.StatusOK {
		t.Fatalf("unexpected code for missing faculty workload: %d", rrWorkloadMissing.Code)
	}
}

func TestComprehensiveComplaintAndMessHandler(t *testing.T) {
	_, _, _, _, messH, _, complaintH := setupTestHandlers()

	// ComplaintHandler errors
	reqCmpPut := httptest.NewRequest(http.MethodPut, "/api/v1/complaints", nil)
	rrCmpPut := httptest.NewRecorder()
	complaintH.HandleComplaints(rrCmpPut, reqCmpPut)
	if rrCmpPut.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for complaints PUT, got %d", rrCmpPut.Code)
	}

	reqCmpBadPost := httptest.NewRequest(http.MethodPost, "/api/v1/complaints", bytes.NewReader([]byte("{invalid")))
	rrCmpBadPost := httptest.NewRecorder()
	complaintH.HandleComplaints(rrCmpBadPost, reqCmpBadPost)
	if rrCmpBadPost.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for complaints bad json, got %d", rrCmpBadPost.Code)
	}

	reqStatusGet := httptest.NewRequest(http.MethodGet, "/api/v1/complaints/status", nil)
	rrStatusGet := httptest.NewRecorder()
	complaintH.HandleComplaintStatus(rrStatusGet, reqStatusGet)
	if rrStatusGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for complaint status GET, got %d", rrStatusGet.Code)
	}

	reqStatusBadPut := httptest.NewRequest(http.MethodPut, "/api/v1/complaints/status", bytes.NewReader([]byte("{invalid")))
	rrStatusBadPut := httptest.NewRecorder()
	complaintH.HandleComplaintStatus(rrStatusBadPut, reqStatusBadPut)
	if rrStatusBadPut.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for complaint status bad json, got %d", rrStatusBadPut.Code)
	}

	// MessHandler errors
	reqMealDel := httptest.NewRequest(http.MethodDelete, "/api/v1/mess/meals", nil)
	rrMealDel := httptest.NewRecorder()
	messH.HandleMeals(rrMealDel, reqMealDel)
	if rrMealDel.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for meals DELETE, got %d", rrMealDel.Code)
	}

	reqMealBadPut := httptest.NewRequest(http.MethodPut, "/api/v1/mess/meals", bytes.NewReader([]byte("{invalid")))
	rrMealBadPut := httptest.NewRecorder()
	messH.HandleMeals(rrMealBadPut, reqMealBadPut)
	if rrMealBadPut.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for meals bad json, got %d", rrMealBadPut.Code)
	}

	reqTtPost := httptest.NewRequest(http.MethodPost, "/api/v1/mess/timetable", nil)
	rrTtPost := httptest.NewRecorder()
	messH.HandleTimetable(rrTtPost, reqTtPost)
	if rrTtPost.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for mess timetable POST, got %d", rrTtPost.Code)
	}

	reqRateDel := httptest.NewRequest(http.MethodDelete, "/api/v1/mess/ratings", nil)
	rrRateDel := httptest.NewRecorder()
	messH.HandleRatings(rrRateDel, reqRateDel)
	if rrRateDel.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 for mess ratings DELETE, got %d", rrRateDel.Code)
	}

	reqRateBadPost := httptest.NewRequest(http.MethodPost, "/api/v1/mess/ratings", bytes.NewReader([]byte("{invalid")))
	rrRateBadPost := httptest.NewRecorder()
	messH.HandleRatings(rrRateBadPost, reqRateBadPost)
	if rrRateBadPost.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for mess ratings bad json, got %d", rrRateBadPost.Code)
	}
}
