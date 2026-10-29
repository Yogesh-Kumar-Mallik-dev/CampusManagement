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

func TestUserAndPermissionFlow(t *testing.T) {
	idSvc := idgen.NewIDService(nil)
	permSvc := service.NewPermissionService(nil, nil)

	// Seed roles and scopes
	permSvc.AddMemoryRole(model.Role{
		Code: "class_rep",
		Permissions: []model.Permission{
			{Code: "attendance:mark"},
		},
	})
	permSvc.AddMemoryScope(model.Scope{
		Code: "sec:cse-3a",
	})

	h := NewUserHandler(idSvc, permSvc)

	// 1. Create 1st Harish
	req1Body := `{"first_name":"Harish","last_name":"Kumar","email":"harish1@campus.edu","admission_year":2025,"entry_type":"lateral","program":"btech"}`
	rec1 := httptest.NewRecorder()
	req1 := httptest.NewRequest(http.MethodPost, "/api/v1/users/student", bytes.NewBufferString(req1Body))
	h.CreateStudent(rec1, req1)

	if rec1.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created, got %d: %s", rec1.Code, rec1.Body.String())
	}

	var res1 map[string]interface{}
	_ = json.Unmarshal(rec1.Body.Bytes(), &res1)
	user1 := res1["user"].(map[string]interface{})
	if user1["campus_handle"] != "harish_2025_l_btech_1" {
		t.Fatalf("expected harish_2025_l_btech_1, got %v", user1["campus_handle"])
	}

	// 2. Create 2nd Harish
	req2Body := `{"first_name":"Harish","last_name":"Sharma","email":"harish2@campus.edu","admission_year":2025,"entry_type":"lateral","program":"btech"}`
	rec2 := httptest.NewRecorder()
	req2 := httptest.NewRequest(http.MethodPost, "/api/v1/users/student", bytes.NewBufferString(req2Body))
	h.CreateStudent(rec2, req2)

	var res2 map[string]interface{}
	_ = json.Unmarshal(rec2.Body.Bytes(), &res2)
	user2 := res2["user"].(map[string]interface{})
	if user2["campus_handle"] != "harish_2025_l_btech_2" {
		t.Fatalf("expected harish_2025_l_btech_2, got %v", user2["campus_handle"])
	}

	// 3. Create 3rd Harish
	req3Body := `{"first_name":"Harish","last_name":"Verma","email":"harish3@campus.edu","admission_year":2025,"entry_type":"lateral","program":"btech"}`
	rec3 := httptest.NewRecorder()
	req3 := httptest.NewRequest(http.MethodPost, "/api/v1/users/student", bytes.NewBufferString(req3Body))
	h.CreateStudent(rec3, req3)

	var res3 map[string]interface{}
	_ = json.Unmarshal(rec3.Body.Bytes(), &res3)
	user3 := res3["user"].(map[string]interface{})
	if user3["campus_handle"] != "harish_2025_l_btech_3" {
		t.Fatalf("expected harish_2025_l_btech_3, got %v", user3["campus_handle"])
	}

	// 4. Create Faculty Dr. Priya (2024)
	facBody := `{"first_name":"Priya","last_name":"Nair","email":"priya@campus.edu","joining_year":2024,"designation":"Assistant Professor"}`
	facRec := httptest.NewRecorder()
	facReq := httptest.NewRequest(http.MethodPost, "/api/v1/users/faculty", bytes.NewBufferString(facBody))
	h.CreateFaculty(facRec, facReq)

	var facRes map[string]interface{}
	_ = json.Unmarshal(facRec.Body.Bytes(), &facRes)
	facUser := facRes["user"].(map[string]interface{})
	if facUser["campus_handle"] != "priya_2024_fac_1" {
		t.Fatalf("expected priya_2024_fac_1, got %v", facUser["campus_handle"])
	}

	// 5. Assign Harish 3 the Class Rep role for Section 3A
	harish3UserID := user3["id"].(string)
	assignBody := `{"user_id":"` + harish3UserID + `","role_code":"class_rep","scope_code":"sec:cse-3a"}`
	assignRec := httptest.NewRecorder()
	assignReq := httptest.NewRequest(http.MethodPost, "/api/v1/permissions/assign", bytes.NewBufferString(assignBody))
	h.AssignRole(assignRec, assignReq)

	if assignRec.Code != http.StatusOK {
		t.Fatalf("expected 200 OK on assign, got %d: %s", assignRec.Code, assignRec.Body.String())
	}

	// 6. Check Permission for sec:cse-3a -> ALLOWED
	chk1Rec := httptest.NewRecorder()
	chk1Req := httptest.NewRequest(http.MethodGet, "/api/v1/permissions/check?user_id="+harish3UserID+"&action=attendance:mark&scope=sec:cse-3a", nil)
	h.CheckPermission(chk1Rec, chk1Req)

	var chk1Res model.PermissionCheckResponse
	_ = json.Unmarshal(chk1Rec.Body.Bytes(), &chk1Res)
	if !chk1Res.Allowed {
		t.Fatalf("expected attendance:mark to be allowed for Harish 3 in sec:cse-3a")
	}

	// 7. Check Permission for sec:cse-3b -> DENIED
	chk2Rec := httptest.NewRecorder()
	chk2Req := httptest.NewRequest(http.MethodGet, "/api/v1/permissions/check?user_id="+harish3UserID+"&action=attendance:mark&scope=sec:cse-3b", nil)
	h.CheckPermission(chk2Rec, chk2Req)

	var chk2Res model.PermissionCheckResponse
	_ = json.Unmarshal(chk2Rec.Body.Bytes(), &chk2Res)
	if chk2Res.Allowed {
		t.Fatalf("expected attendance:mark to be DENIED for Harish 3 in sec:cse-3b")
	}
}
