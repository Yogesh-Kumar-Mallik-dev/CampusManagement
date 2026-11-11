package handler

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"campus/backend/internal/idgen"
	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

func setupTestHandlers() (*AcademicHandler, *DepartmentHandler, *UserHandler, *HostelHandler, *MessHandler, *AuthHandler, *ComplaintHandler) {
	permSvc := service.NewPermissionService(nil, nil)
	idSvc := idgen.NewIDService(nil)
	acadSvc := service.NewAcademicService(nil, nil, permSvc)
	hostelSvc := service.NewHostelService(nil, permSvc)
	hostelSvc.SeedDefaultRooms()
	messSvc := service.NewMessService(nil, permSvc)
	messSvc.SeedDefaultMenuAndReviews()
	complaintSvc := service.NewComplaintService()

	userH := NewUserHandler(idSvc, permSvc)
	userH.users["usr-priya_2024_emp_1"] = model.User{
		BaseSyncModel: model.BaseSyncModel{ID: "usr-priya_2024_emp_1"},
		CampusHandle:  "priya_2024_emp_1",
		FirstName:     "Dr. Priya",
		LastName:      "Nair",
		Archetype:     model.ArchetypeEmployee,
		IsActive:      true,
		Status:        "active",
	}
	userH.handleToID["priya_2024_emp_1"] = "usr-priya_2024_emp_1"
	userH.employeeRecords["usr-priya_2024_emp_1"] = model.EmployeeRecord{
		UserID:     "usr-priya_2024_emp_1",
		IsAcademic: true,
	}
	acadH := NewAcademicHandler(acadSvc)
	deptH := NewDepartmentHandler(acadSvc, userH.FindUser, userH.ListTeachers)
	hostelH := NewHostelHandler(hostelSvc)
	messH := NewMessHandler(messSvc)
	authH := NewAuthHandler(permSvc)
	complaintH := NewComplaintHandler(complaintSvc)

	return acadH, deptH, userH, hostelH, messH, authH, complaintH
}

func TestHandlerExpansionEndOpticalAndEdgeCases(t *testing.T) {
	acadH, deptH, userH, hostelH, messH, authH, complaintH := setupTestHandlers()

	// 1. AcademicHandler: EndOpticalSession
	// First start a session
	startPayload := map[string]interface{}{
		"course_id":         "crs-cs101",
		"course_code":       "CS101",
		"course_name":       "Intro to CS",
		"room_number":       "LH-1",
		"scope_code":        "sec:cse-1a",
		"marked_by_user_id": "usr-faculty-1",
		"marked_by_name":    "Prof Test",
		"refresh_interval":  1500,
	}
	body, _ := json.Marshal(startPayload)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/attendance/optical/start", bytes.NewReader(body))
	rr := httptest.NewRecorder()
	acadH.StartOpticalSession(rr, req)
	if rr.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created from StartOpticalSession, got %d", rr.Code)
	}

	var startedSession model.OpticalAttendanceSession
	_ = json.Unmarshal(rr.Body.Bytes(), &startedSession)

	// End session
	endPayload := map[string]string{"session_id": startedSession.ID}
	endBody, _ := json.Marshal(endPayload)
	reqEnd := httptest.NewRequest(http.MethodPost, "/api/v1/attendance/optical/end", bytes.NewReader(endBody))
	rrEnd := httptest.NewRecorder()
	acadH.EndOpticalSession(rrEnd, reqEnd)
	if rrEnd.Code != http.StatusOK {
		t.Fatalf("expected 200 OK from EndOpticalSession, got %d", rrEnd.Code)
	}

	// End with invalid method
	reqEndGet := httptest.NewRequest(http.MethodGet, "/api/v1/attendance/optical/end", nil)
	rrEndGet := httptest.NewRecorder()
	acadH.EndOpticalSession(rrEndGet, reqEndGet)
	if rrEndGet.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 MethodNotAllowed, got %d", rrEndGet.Code)
	}

	// MethodNotAllowed and missing parameters across Academic endpoints
	reqBad := httptest.NewRequest(http.MethodPatch, "/api/v1/academics/courses", nil)
	rrBad := httptest.NewRecorder()
	acadH.HandleCourses(rrBad, reqBad)
	if rrBad.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405, got %d", rrBad.Code)
	}

	reqNoScope := httptest.NewRequest(http.MethodGet, "/api/v1/academics/timetable", nil)
	rrNoScope := httptest.NewRecorder()
	acadH.HandleTimetable(rrNoScope, reqNoScope)
	if rrNoScope.Code != http.StatusOK {
		t.Fatalf("expected 200 for empty scope query, got %d", rrNoScope.Code)
	}

	// 2. DepartmentHandler: HandlePrograms, HandleTeachers, HandleLabBatches
	// Programs GET and POST
	reqProgList := httptest.NewRequest(http.MethodGet, "/api/v1/academics/programs", nil)
	rrProgList := httptest.NewRecorder()
	deptH.HandlePrograms(rrProgList, reqProgList)
	if rrProgList.Code != http.StatusOK {
		t.Fatalf("expected 200 OK from HandlePrograms, got %d", rrProgList.Code)
	}

	progData := map[string]interface{}{
		"code":            "BTECH-IT",
		"name":            "B.Tech Information Technology",
		"degree_level":    "undergraduate",
		"total_semesters": 8,
		"has_branches":    true,
		"branch":          "Information Technology",
		"duration_years":  4,
		"branches":        []string{"Information Technology", "Cyber Security"},
	}
	progBody, _ := json.Marshal(progData)
	reqProgCreate := httptest.NewRequest(http.MethodPost, "/api/v1/academics/programs", bytes.NewReader(progBody))
	rrProgCreate := httptest.NewRecorder()
	deptH.HandlePrograms(rrProgCreate, reqProgCreate)
	if rrProgCreate.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created from HandlePrograms POST, got %d", rrProgCreate.Code)
	}

	reqProgInvalidMethod := httptest.NewRequest(http.MethodDelete, "/api/v1/academics/programs", nil)
	rrProgInvalidMethod := httptest.NewRecorder()
	deptH.HandlePrograms(rrProgInvalidMethod, reqProgInvalidMethod)
	if rrProgInvalidMethod.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 MethodNotAllowed from HandlePrograms DELETE, got %d", rrProgInvalidMethod.Code)
	}

	// Teachers GET
	reqTeachers := httptest.NewRequest(http.MethodGet, "/api/v1/academics/teachers", nil)
	rrTeachers := httptest.NewRecorder()
	deptH.HandleTeachers(rrTeachers, reqTeachers)
	if rrTeachers.Code != http.StatusOK {
		t.Fatalf("expected 200 OK from HandleTeachers, got %d", rrTeachers.Code)
	}

	// LabBatches GET and POST
	reqBatches := httptest.NewRequest(http.MethodGet, "/api/v1/academics/sections/batches?section_id=sec-sem1-cse-a", nil)
	rrBatches := httptest.NewRecorder()
	deptH.HandleLabBatches(rrBatches, reqBatches)
	if rrBatches.Code != http.StatusOK {
		t.Fatalf("expected 200 OK from HandleLabBatches GET, got %d", rrBatches.Code)
	}

	batchPayload := map[string]interface{}{
		"section_id": "sec-sem1-cse-a",
		"name":       "Batch A1",
	}
	batchBody, _ := json.Marshal(batchPayload)
	reqBatchCreate := httptest.NewRequest(http.MethodPost, "/api/v1/academics/sections/batches", bytes.NewReader(batchBody))
	rrBatchCreate := httptest.NewRecorder()
	deptH.HandleLabBatches(rrBatchCreate, reqBatchCreate)
	if rrBatchCreate.Code != http.StatusCreated && rrBatchCreate.Code != http.StatusBadRequest {
		t.Fatalf("unexpected code from HandleLabBatches POST: %d", rrBatchCreate.Code)
	}

	// 3. MessHandler: HandleMeals method check (GET not allowed)
	reqMeals := httptest.NewRequest(http.MethodGet, "/api/v1/mess/meals?meal_id=meal-mon-lunch", nil)
	rrMeals := httptest.NewRecorder()
	messH.HandleMeals(rrMeals, reqMeals)
	if rrMeals.Code != http.StatusMethodNotAllowed {
		t.Fatalf("unexpected code from HandleMeals GET: %d", rrMeals.Code)
	}

	mealUpdate := map[string]interface{}{
		"id":           "meal-monday-lunch",
		"day_of_week":  "monday",
		"meal_type":    "lunch",
		"menu_summary": "Paneer Makhani, Naan, Rice",
	}
	mealBody, _ := json.Marshal(mealUpdate)
	reqMealPut := httptest.NewRequest(http.MethodPut, "/api/v1/mess/meals", bytes.NewReader(mealBody))
	rrMealPut := httptest.NewRecorder()
	messH.HandleMeals(rrMealPut, reqMealPut)
	if rrMealPut.Code != http.StatusOK && rrMealPut.Code != http.StatusNotFound {
		t.Fatalf("unexpected code from HandleMeals PUT: %d", rrMealPut.Code)
	}

	// 4. UserHandler: AssignRole and ListTeachers
	teachers := userH.ListTeachers()
	if len(teachers) == 0 {
		t.Fatalf("expected default teachers list")
	}

	assignRoleData := map[string]interface{}{
		"user_id":    "usr-priya_2024_emp_1",
		"role_code":  "faculty",
		"scope_code": "dept:cse",
	}
	assignBody, _ := json.Marshal(assignRoleData)
	reqAssignRole := httptest.NewRequest(http.MethodPost, "/api/v1/permissions/assign", bytes.NewReader(assignBody))
	rrAssignRole := httptest.NewRecorder()
	userH.AssignRole(rrAssignRole, reqAssignRole)
	if rrAssignRole.Code != http.StatusOK {
		t.Fatalf("expected 200 OK from AssignRole, got %d", rrAssignRole.Code)
	}

	// 5. HostelHandler: HandleRooms PUT, HandleAssets PUT & DELETE, HandleOccupants DELETE
	roomUpdate := map[string]interface{}{
		"original_room_number": 101,
		"new_room_number":      191,
		"block_name":           "Kalam Block",
	}
	roomPutBody, _ := json.Marshal(roomUpdate)
	reqRoomPut := httptest.NewRequest(http.MethodPut, "/api/v1/hostel/rooms", bytes.NewReader(roomPutBody))
	rrRoomPut := httptest.NewRecorder()
	hostelH.HandleRooms(rrRoomPut, reqRoomPut)
	if rrRoomPut.Code != http.StatusOK {
		t.Fatalf("expected 200 OK from HandleRooms PUT, got %d (%s)", rrRoomPut.Code, rrRoomPut.Body.String())
	}

	assetUpdate := map[string]interface{}{
		"room_number":   191,
		"asset_id":      "asset-101-bed-1",
		"serial_number": "BED-191-01",
		"condition":     "good",
	}
	assetPutBody, _ := json.Marshal(assetUpdate)
	reqAssetPut := httptest.NewRequest(http.MethodPut, "/api/v1/hostel/rooms/assets", bytes.NewReader(assetPutBody))
	rrAssetPut := httptest.NewRecorder()
	hostelH.HandleAssets(rrAssetPut, reqAssetPut)

	// Remove occupant
	removeOccData := map[string]interface{}{
		"room_number": 191,
		"user_id":     "usr-harish_2025_l_btech_1",
	}
	occDelBody, _ := json.Marshal(removeOccData)
	reqOccDel := httptest.NewRequest(http.MethodDelete, "/api/v1/hostel/rooms/occupants", bytes.NewReader(occDelBody))
	rrOccDel := httptest.NewRecorder()
	hostelH.HandleOccupants(rrOccDel, reqOccDel)

	// Remove asset
	removeAssetData := map[string]interface{}{
		"room_number": 191,
		"asset_id":    "asset-101-bed-1",
	}
	assetDelBody, _ := json.Marshal(removeAssetData)
	reqAssetDel := httptest.NewRequest(http.MethodDelete, "/api/v1/hostel/rooms/assets", bytes.NewReader(assetDelBody))
	rrAssetDel := httptest.NewRecorder()
	hostelH.HandleAssets(rrAssetDel, reqAssetDel)

	// 6. AuthHandler: Invalid login and method
	authBadMethod := httptest.NewRequest(http.MethodGet, "/api/v1/auth/login", nil)
	rrAuthBad := httptest.NewRecorder()
	authH.Login(rrAuthBad, authBadMethod)
	if rrAuthBad.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 MethodNotAllowed from Login GET, got %d", rrAuthBad.Code)
	}

	authEmptyUser := map[string]string{
		"identifier": "",
		"password":   "anypass",
	}
	emptyUserBody, _ := json.Marshal(authEmptyUser)
	reqAuthEmpty := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(emptyUserBody))
	rrAuthEmpty := httptest.NewRecorder()
	authH.Login(rrAuthEmpty, reqAuthEmpty)
	if rrAuthEmpty.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 BadRequest for empty user identifier, got %d", rrAuthEmpty.Code)
	}

	reqAuthBadJson := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader([]byte("{invalid-json")))
	rrAuthBadJson := httptest.NewRecorder()
	authH.Login(rrAuthBadJson, reqAuthBadJson)
	if rrAuthBadJson.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 BadRequest for invalid json, got %d", rrAuthBadJson.Code)
	}

	// 7. ComplaintHandler: HandleComplaintStatus PUT error cases
	badComplaintStatus := map[string]string{
		"complaint_id": "non_existent_cmp",
		"status":       "resolved",
	}
	badCmpBody, _ := json.Marshal(badComplaintStatus)
	reqCmpBad := httptest.NewRequest(http.MethodPut, "/api/v1/complaints/status", bytes.NewReader(badCmpBody))
	rrCmpBad := httptest.NewRecorder()
	complaintH.HandleComplaintStatus(rrCmpBad, reqCmpBad)
	if rrCmpBad.Code != http.StatusBadRequest && rrCmpBad.Code != http.StatusNotFound && rrCmpBad.Code != http.StatusInternalServerError {
		t.Fatalf("expected error from HandleComplaintStatus for missing complaint, got %d", rrCmpBad.Code)
	}
}
