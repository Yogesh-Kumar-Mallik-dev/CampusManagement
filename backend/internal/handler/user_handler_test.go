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
