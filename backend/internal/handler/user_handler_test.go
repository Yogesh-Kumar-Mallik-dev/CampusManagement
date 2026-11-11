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

func TestUserAndDualRoleEmployeeFlow(t *testing.T) {
	idSvc := idgen.NewIDService(nil)
	permSvc := service.NewPermissionService(nil, nil)

	// Seed roles and scopes
	permSvc.AddMemoryRole(model.Role{
		Code: "class_rep",
		Permissions: []model.Permission{
			{Code: "attendance:mark"},
		},
	})
	permSvc.AddMemoryRole(model.Role{
		Code: "professor",
		Permissions: []model.Permission{
			{Code: "syllabus:update"},
			{Code: "attendance:approve"},
		},
	})
	permSvc.AddMemoryRole(model.Role{
		Code: "dean_student_affairs",
		Permissions: []model.Permission{
			{Code: "budget:approve"},
			{Code: "disciplinary:action"},
		},
	})

	permSvc.AddMemoryScope(model.Scope{Code: "sec:cse-3a"})
	permSvc.AddMemoryScope(model.Scope{Code: "dept:cse"})
	permSvc.AddMemoryScope(model.Scope{Code: "unit:student_affairs"})

	h := NewUserHandler(idSvc, permSvc)

	// 1. Create Student Harish
	reqStudentBody := `{"first_name":"Harish","last_name":"Kumar","email":"harish@campus.edu","admission_year":2025,"entry_type":"lateral","program":"btech"}`
	recStudent := httptest.NewRecorder()
	reqStudent := httptest.NewRequest(http.MethodPost, "/api/v1/users/student", bytes.NewBufferString(reqStudentBody))
	h.CreateStudent(recStudent, reqStudent)

	if recStudent.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created, got %d", recStudent.Code)
	}

	var resStudent map[string]interface{}
	_ = json.Unmarshal(recStudent.Body.Bytes(), &resStudent)
	stuUser := resStudent["user"].(map[string]interface{})
	if stuUser["campus_handle"] != "harish_2025_l_btech_1" {
		t.Fatalf("expected harish_2025_l_btech_1, got %v", stuUser["campus_handle"])
	}

	// 2. Create Employee Dr. Priya who is BOTH Academic (Professor) AND Administrative (Dean)
	reqPriyaBody := `{
		"first_name": "Priya",
		"last_name": "Nair",
		"email": "priya@campus.edu",
		"joining_year": 2024,
		"employment_type": "permanent",
		"is_academic": true,
		"academic_rank": "Professor",
		"cabin_location": "CS-302",
		"department_affiliations": ["dept:cse"],
		"is_administrative": true,
		"primary_unit": "unit:student_affairs",
		"designation": "Dean of Student Affairs",
		"office_location": "Admin-101"
	}`
	recPriya := httptest.NewRecorder()
	reqPriya := httptest.NewRequest(http.MethodPost, "/api/v1/users/employee", bytes.NewBufferString(reqPriyaBody))
	h.CreateEmployee(recPriya, reqPriya)

	if recPriya.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created, got %d: %s", recPriya.Code, recPriya.Body.String())
	}

	var resPriya map[string]interface{}
	_ = json.Unmarshal(recPriya.Body.Bytes(), &resPriya)
	priyaUser := resPriya["user"].(map[string]interface{})
	priyaHandle := priyaUser["campus_handle"].(string)

	if priyaHandle != "priya_2024_emp_1" {
		t.Fatalf("expected priya_2024_emp_1, got %s", priyaHandle)
	}

	// Verify both profiles are populated
	if resPriya["academic_profile"] == nil {
		t.Fatalf("expected academic_profile to be present")
	}
	if resPriya["administrative_profile"] == nil {
		t.Fatalf("expected administrative_profile to be present")
	}

	// 3. Assign Dr. Priya her dual roles:
	// Hat A: Professor for dept:cse
	// Hat B: Dean for unit:student_affairs
	priyaID := priyaUser["id"].(string)
	_ = permSvc.AssignRole(reqPriya.Context(), priyaID, "professor", "dept:cse", nil)
	_ = permSvc.AssignRole(reqPriya.Context(), priyaID, "dean_student_affairs", "unit:student_affairs", nil)

	// 4. Test Hat A: Academic Action (attendance:approve in dept:cse)
	chkA := httptest.NewRecorder()
	reqA := httptest.NewRequest(http.MethodGet, "/api/v1/permissions/check?user_id="+priyaID+"&action=attendance:approve&scope=dept:cse", nil)
	h.CheckPermission(chkA, reqA)

	var resA model.PermissionCheckResponse
	_ = json.Unmarshal(chkA.Body.Bytes(), &resA)
	if !resA.Allowed {
		t.Fatalf("expected Dr. Priya to be allowed to approve attendance in dept:cse")
	}

	// 5. Test Hat B: Administrative Action (budget:approve in unit:student_affairs)
	chkB := httptest.NewRecorder()
	reqB := httptest.NewRequest(http.MethodGet, "/api/v1/permissions/check?user_id="+priyaID+"&action=budget:approve&scope=unit:student_affairs", nil)
	h.CheckPermission(chkB, reqB)

	var resB model.PermissionCheckResponse
	_ = json.Unmarshal(chkB.Body.Bytes(), &resB)
	if !resB.Allowed {
		t.Fatalf("expected Dr. Priya to be allowed to approve budget in unit:student_affairs")
	}

	// 6. Test Hat Conflict: Can Dr. Priya approve budget in dept:cse? NO! (Dean budget approval is for student affairs only)
	chkC := httptest.NewRecorder()
	reqC := httptest.NewRequest(http.MethodGet, "/api/v1/permissions/check?user_id="+priyaID+"&action=budget:approve&scope=dept:cse", nil)
	h.CheckPermission(chkC, reqC)

	var resC model.PermissionCheckResponse
	_ = json.Unmarshal(chkC.Body.Bytes(), &resC)
	if resC.Allowed {
		t.Fatalf("expected budget approval in dept:cse to be denied")
	}

	// 7. Test User Discontinuation & Security Revocation
	disReqBody := `{"user_id":"` + priyaID + `","status":"resigned","reason":"Accepted tenure at MIT","discontinued_by":"usr-admin"}`
	disRec := httptest.NewRecorder()
	disReq := httptest.NewRequest(http.MethodPost, "/api/v1/users/discontinue", bytes.NewBufferString(disReqBody))
	h.DiscontinueUser(disRec, disReq)

	if disRec.Code != http.StatusOK {
		t.Fatalf("expected 200 OK on discontinue, got %d: %s", disRec.Code, disRec.Body.String())
	}

	// Verify permissions revoked immediately
	chkRevoked := httptest.NewRecorder()
	reqRevoked := httptest.NewRequest(http.MethodGet, "/api/v1/permissions/check?user_id="+priyaID+"&action=attendance:approve&scope=dept:cse", nil)
	h.CheckPermission(chkRevoked, reqRevoked)
	var resRevoked model.PermissionCheckResponse
	_ = json.Unmarshal(chkRevoked.Body.Bytes(), &resRevoked)
	if resRevoked.Allowed {
		t.Fatalf("expected permissions to be revoked after discontinuation")
	}

	// 8. Test Reactivation
	reReqBody := `{"user_id":"` + priyaID + `"}`
	reRec := httptest.NewRecorder()
	reReq := httptest.NewRequest(http.MethodPost, "/api/v1/users/reactivate", bytes.NewBufferString(reReqBody))
	h.ReactivateUser(reRec, reReq)

	if reRec.Code != http.StatusOK {
		t.Fatalf("expected 200 OK on reactivate, got %d: %s", reRec.Code, reRec.Body.String())
	}

	// 9. Test User Profile
	profRec := httptest.NewRecorder()
	profReq := httptest.NewRequest(http.MethodGet, "/api/v1/users/profile?id="+priyaID, nil)
	h.GetUserProfile(profRec, profReq)

	if profRec.Code != http.StatusOK {
		t.Fatalf("expected 200 OK on profile, got %d", profRec.Code)
	}
	var profResp model.UserProfileResponse
	_ = json.Unmarshal(profRec.Body.Bytes(), &profResp)
	if profResp.User.Status != "active" || profResp.AcademicProfile == nil {
		t.Fatalf("invalid profile response: %+v", profResp)
	}

	// 10. Test User List with Search & Status filters
	listRec := httptest.NewRecorder()
	listReq := httptest.NewRequest(http.MethodGet, "/api/v1/users?search=priya", nil)
	h.HandleUsers(listRec, listReq)

	if listRec.Code != http.StatusOK {
		t.Fatalf("expected 200 OK on list, got %d", listRec.Code)
	}
	var usersList []model.User
	_ = json.Unmarshal(listRec.Body.Bytes(), &usersList)
	if len(usersList) == 0 {
		t.Fatalf("expected at least 1 user matching search 'priya'")
	}
}

func TestContractorOnboardingAndProfile(t *testing.T) {
	idSvc := idgen.NewIDService(nil)
	permSvc := service.NewPermissionService(nil, nil)
	permSvc.AddMemoryRole(model.Role{
		Code: "vendor_staff",
		Permissions: []model.Permission{
			{Code: "facility:access"},
		},
	})
	permSvc.AddMemoryScope(model.Scope{Code: "gate:main"})
	permSvc.AddMemoryScope(model.Scope{Code: "building:canteen"})

	h := NewUserHandler(idSvc, permSvc)

	// 1. Onboard Contractor Mukesh
	contractorJSON := `{
		"first_name": "Mukesh",
		"last_name": "Verma",
		"email": "mukesh.verma@sodexo.com",
		"personal_email": "m.verma@personal.com",
		"phone": "+91 98333 44556",
		"onboarding_year": 2025,
		"vendor_organization": "Sodexo Campus Dining",
		"service_type": "canteen",
		"gate_pass_id": "GP-2025-0891",
		"supervisor_name": "Anil Kapoor",
		"supervisor_phone": "+91 98222 11000",
		"permitted_scopes": ["gate:main", "building:canteen"]
	}`

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/users/contractor", bytes.NewBufferString(contractorJSON))
	h.CreateContractor(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created for contractor, got %d: %s", rec.Code, rec.Body.String())
	}

	var res map[string]interface{}
	_ = json.Unmarshal(rec.Body.Bytes(), &res)
	u := res["user"].(map[string]interface{})
	cp := res["contractor_profile"].(map[string]interface{})

	handle := u["campus_handle"].(string)
	if handle != "mukesh_2025_ext_1" && handle != "mukesh_2025_ext_2" {
		t.Fatalf("unexpected contractor handle: %s", handle)
	}
	if u["archetype"] != "external" {
		t.Fatalf("expected archetype external, got %v", u["archetype"])
	}
	if cp["vendor_organization"] != "Sodexo Campus Dining" {
		t.Fatalf("expected Sodexo Campus Dining, got %v", cp["vendor_organization"])
	}

	// 2. Query Contractor Profile
	profRec := httptest.NewRecorder()
	profReq := httptest.NewRequest(http.MethodGet, "/api/v1/users/profile?handle="+handle, nil)
	h.GetUserProfile(profRec, profReq)

	if profRec.Code != http.StatusOK {
		t.Fatalf("expected 200 OK for contractor profile, got %d", profRec.Code)
	}

	var profResp model.UserProfileResponse
	_ = json.Unmarshal(profRec.Body.Bytes(), &profResp)
	if profResp.ContractorProfile == nil {
		t.Fatalf("expected contractor_profile to be present in profile response")
	}
	if profResp.ContractorProfile.VendorOrganization != "Sodexo Campus Dining" {
		t.Fatalf("vendor organization mismatch: %s", profResp.ContractorProfile.VendorOrganization)
	}

	// 3. Query Users Filtered by Archetype External
	listRec := httptest.NewRecorder()
	listReq := httptest.NewRequest(http.MethodGet, "/api/v1/users?archetype=external", nil)
	h.HandleUsers(listRec, listReq)

	if listRec.Code != http.StatusOK {
		t.Fatalf("expected 200 OK for archetype=external, got %d", listRec.Code)
	}

	var externals []model.User
	_ = json.Unmarshal(listRec.Body.Bytes(), &externals)
	if len(externals) == 0 {
		t.Fatalf("expected at least 1 contractor in list")
	}
}

func TestGetUserRolesEndpoint(t *testing.T) {
	idSvc := idgen.NewIDService(nil)
	permSvc := service.NewPermissionService(nil, nil)
	permSvc.AddMemoryRole(model.Role{
		Code: "admin",
		Name: "Campus Administrator",
		Permissions: []model.Permission{
			{Code: "*"},
		},
	})
	permSvc.AddMemoryRole(model.Role{
		Code: "faculty",
		Name: "Faculty Member",
		Permissions: []model.Permission{
			{Code: "timetable:edit"},
		},
	})

	h := NewUserHandler(idSvc, permSvc)

	// Query roles for seeded admin
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/users/roles?handle=campus_admin", nil)
	h.GetUserRoles(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d", rec.Code)
	}

	var res map[string]interface{}
	if err := json.Unmarshal(rec.Body.Bytes(), &res); err != nil {
		t.Fatalf("failed decoding json: %v", err)
	}

	roles, ok := res["roles"].([]interface{})
	if !ok || len(roles) == 0 {
		t.Fatalf("expected assigned roles for campus_admin, got %v", res["roles"])
	}

	perms, ok := res["permissions"].([]interface{})
	if !ok || len(perms) == 0 {
		t.Fatalf("expected permissions for campus_admin, got %v", res["permissions"])
	}
}

func TestUpdateUserProfile(t *testing.T) {
	idSvc := idgen.NewIDService(nil)
	permSvc := service.NewPermissionService(nil, nil)
	h := NewUserHandler(idSvc, permSvc)

	// Set up test user Harish for this test
	h.users["usr-harish_2025_l_btech_1"] = model.User{
		BaseSyncModel: model.BaseSyncModel{ID: "usr-harish_2025_l_btech_1"},
		CampusHandle:  "harish_2025_l_btech_1",
		FirstName:     "Harish",
		LastName:      "Kumar",
		Archetype:     model.ArchetypeStudent,
		IsActive:      true,
		Status:        "active",
	}
	h.handleToID["harish_2025_l_btech_1"] = "usr-harish_2025_l_btech_1"

	// Update Harish's contact info
	updateBody := `{
		"user_id": "usr-harish_2025_l_btech_1",
		"personal_email": "harish.new@example.com",
		"phone": "+91 99887 76655",
		"emergency_contact_name": "Anita Kumar (Mother)",
		"emergency_contact_phone": "+91 99887 00011",
		"bloodGroup": "O+",
		"address": "Flat 302, Green Valley Apartments"
	}`
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/users/profile/update", bytes.NewBufferString(updateBody))
	h.UpdateUserProfile(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d (body: %s)", rec.Code, rec.Body.String())
	}

	var user model.User
	if err := json.Unmarshal(rec.Body.Bytes(), &user); err != nil {
		t.Fatalf("failed decoding json: %v", err)
	}

	if user.PersonalEmail != "harish.new@example.com" {
		t.Fatalf("expected personal_email harish.new@example.com, got %s", user.PersonalEmail)
	}
	if user.Phone != "+91 99887 76655" {
		t.Fatalf("expected phone +91 99887 76655, got %s", user.Phone)
	}
	if user.EmergencyContactName != "Anita Kumar (Mother)" {
		t.Fatalf("expected emergency contact name Anita Kumar (Mother), got %s", user.EmergencyContactName)
	}
	if user.Address != "Flat 302, Green Valley Apartments" {
		t.Fatalf("expected address Flat 302, Green Valley Apartments, got %s", user.Address)
	}
}

func TestRoleAndPermissionAssignmentForEmployeesAndStudents(t *testing.T) {
	idSvc := idgen.NewIDService(nil)
	permSvc := service.NewPermissionService(nil, nil)

	// Register roles
	permSvc.AddMemoryRole(model.Role{
		Code: "coordinator",
		Name: "Section Coordinator",
		Permissions: []model.Permission{
			{Code: "attendance:mark"},
			{Code: "attendance:set_criteria"},
			{Code: "timetable:edit"},
		},
	})
	permSvc.AddMemoryRole(model.Role{
		Code: "library_incharge",
		Name: "Library In-Charge",
		Permissions: []model.Permission{
			{Code: "library:issue"},
			{Code: "library:return"},
			{Code: "library:manage_inventory"},
		},
	})
	permSvc.AddMemoryRole(model.Role{
		Code: "hod",
		Name: "Head of Department",
		Permissions: []model.Permission{
			{Code: "department:manage"},
			{Code: "attendance:approve"},
		},
	})
	permSvc.AddMemoryRole(model.Role{
		Code: "class_representative",
		Name: "Class Representative",
		Permissions: []model.Permission{
			{Code: "attendance:mark"},
			{Code: "notice:section_post"},
		},
	})
	permSvc.AddMemoryRole(model.Role{
		Code: "club_president",
		Name: "Club President",
		Permissions: []model.Permission{
			{Code: "club:publish_event"},
			{Code: "club:manage_members"},
		},
	})

	h := NewUserHandler(idSvc, permSvc)

	// 1. Create Employee Dr. Sharma
	reqEmpBody := `{"first_name":"Rajesh","last_name":"Sharma","email":"rajesh.sharma@campus.edu","joining_year":2024,"employment_type":"permanent","is_academic":true}`
	recEmp := httptest.NewRecorder()
	reqEmp := httptest.NewRequest(http.MethodPost, "/api/v1/users/employee", bytes.NewBufferString(reqEmpBody))
	h.CreateEmployee(recEmp, reqEmp)
	if recEmp.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created for employee, got %d", recEmp.Code)
	}
	var empRes map[string]interface{}
	_ = json.Unmarshal(recEmp.Body.Bytes(), &empRes)
	empUser := empRes["user"].(map[string]interface{})
	empID := empUser["id"].(string)

	// 2. Create Student Ananya
	reqStuBody := `{"first_name":"Ananya","last_name":"Roy","email":"ananya.roy@campus.edu","admission_year":2025,"entry_type":"regular","program":"btech"}`
	recStu := httptest.NewRecorder()
	reqStu := httptest.NewRequest(http.MethodPost, "/api/v1/users/student", bytes.NewBufferString(reqStuBody))
	h.CreateStudent(recStu, reqStu)
	if recStu.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created for student, got %d", recStu.Code)
	}
	var stuRes map[string]interface{}
	_ = json.Unmarshal(recStu.Body.Bytes(), &stuRes)
	stuUser := stuRes["user"].(map[string]interface{})
	stuID := stuUser["id"].(string)

	// 3. Assign Employee Roles: coordinator, library_incharge, hod
	rolesToAssignEmp := []struct {
		Role  string
		Scope string
	}{
		{"coordinator", "sec:cse-3a"},
		{"library_incharge", "global"},
		{"hod", "dept:cse"},
	}
	for _, r := range rolesToAssignEmp {
		payload, _ := json.Marshal(map[string]interface{}{
			"user_id":    empID,
			"role_code":  r.Role,
			"scope_code": r.Scope,
		})
		recAssign := httptest.NewRecorder()
		reqAssign := httptest.NewRequest(http.MethodPost, "/api/v1/permissions/assign", bytes.NewReader(payload))
		h.AssignRole(recAssign, reqAssign)
		if recAssign.Code != http.StatusOK {
			t.Fatalf("failed assigning role %s to employee: %s", r.Role, recAssign.Body.String())
		}
	}

	// 4. Assign Student Roles: class_representative, Club:Example:president
	rolesToAssignStu := []struct {
		Role  string
		Scope string
	}{
		{"class_representative", "sec:cse-3a"},
		{"club_president", "Club:Example:president"},
	}
	for _, r := range rolesToAssignStu {
		payload, _ := json.Marshal(map[string]interface{}{
			"user_id":    stuID,
			"role_code":  r.Role,
			"scope_code": r.Scope,
		})
		recAssign := httptest.NewRecorder()
		reqAssign := httptest.NewRequest(http.MethodPost, "/api/v1/permissions/assign", bytes.NewReader(payload))
		h.AssignRole(recAssign, reqAssign)
		if recAssign.Code != http.StatusOK {
			t.Fatalf("failed assigning role %s to student: %s", r.Role, recAssign.Body.String())
		}
	}

	// 5. Verify Employee permissions
	recEmpRoles := httptest.NewRecorder()
	reqEmpRoles := httptest.NewRequest(http.MethodGet, "/api/v1/users/roles?user_id="+empID, nil)
	h.GetUserRoles(recEmpRoles, reqEmpRoles)
	if recEmpRoles.Code != http.StatusOK {
		t.Fatalf("failed getting employee roles: %s", recEmpRoles.Body.String())
	}
	var empRoleData map[string]interface{}
	_ = json.Unmarshal(recEmpRoles.Body.Bytes(), &empRoleData)
	empPerms := empRoleData["permissions"].([]interface{})
	if len(empPerms) < 5 {
		t.Fatalf("expected at least 5 permissions for employee with 3 roles, got %d (%v)", len(empPerms), empPerms)
	}

	// Verify Student permissions
	recStuRoles := httptest.NewRecorder()
	reqStuRoles := httptest.NewRequest(http.MethodGet, "/api/v1/users/roles?user_id="+stuID, nil)
	h.GetUserRoles(recStuRoles, reqStuRoles)
	if recStuRoles.Code != http.StatusOK {
		t.Fatalf("failed getting student roles: %s", recStuRoles.Body.String())
	}
	var stuRoleData map[string]interface{}
	_ = json.Unmarshal(recStuRoles.Body.Bytes(), &stuRoleData)
	stuPerms := stuRoleData["permissions"].([]interface{})
	if len(stuPerms) < 3 {
		t.Fatalf("expected at least 3 permissions for student with CR and Club President, got %d (%v)", len(stuPerms), stuPerms)
	}

	// Verify Can checks
	allowed, _ := permSvc.Can(nil, empID, "attendance:set_criteria", "sec:cse-3a")
	if !allowed {
		t.Errorf("expected coordinator to be allowed attendance:set_criteria")
	}
	allowedLib, _ := permSvc.Can(nil, empID, "library:issue", "global")
	if !allowedLib {
		t.Errorf("expected library_incharge to be allowed library:issue")
	}
	allowedClub, _ := permSvc.Can(nil, stuID, "club:publish_event", "Club:Example:president")
	if !allowedClub {
		t.Errorf("expected Club:Example:president to be allowed club:publish_event")
	}
}
