package handler

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"campus/backend/internal/idgen"
	"campus/backend/internal/model"
)

func TestAuthHandlerLogin(t *testing.T) {
	h := NewAuthHandler(nil)

	payload := LoginRequest{
		Identifier: "harish_2025_l_btech_1",
		Password:   "campus123",
	}
	body, _ := json.Marshal(payload)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(body))
	w := httptest.NewRecorder()

	h.Login(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Expected status 200, got %d", w.Code)
	}

	var resp LoginResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if resp.User.CampusHandle != "harish_2025_l_btech_1" {
		t.Errorf("Expected handle harish_2025_l_btech_1, got %s", resp.User.CampusHandle)
	}
	if len(resp.Scopes) == 0 {
		t.Errorf("Expected user scopes, got none")
	}

	// Test Admin Login
	adminPayload := LoginRequest{
		Identifier: "admin@campus.edu",
		Password:   "admin123",
	}
	adminBody, _ := json.Marshal(adminPayload)
	adminReq := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(adminBody))
	adminRec := httptest.NewRecorder()
	h.Login(adminRec, adminReq)

	if adminRec.Code != http.StatusOK {
		t.Fatalf("Expected admin login status 200, got %d", adminRec.Code)
	}
	var adminResp LoginResponse
	if err := json.NewDecoder(adminRec.Body).Decode(&adminResp); err != nil {
		t.Fatalf("Failed decoding admin response: %v", err)
	}
	if adminResp.User.CampusHandle != "campus_admin" {
		t.Errorf("Expected campus_admin handle, got %s", adminResp.User.CampusHandle)
	}
}

func TestInitialCreationUsernamePasswordSameAndForcedChange(t *testing.T) {
	idGen := idgen.NewIDService(nil)
	userH := NewUserHandler(idGen, nil)
	authH := NewAuthHandler(nil, userH)

	// 1. Create a new student user
	createStuPayload := CreateStudentRequest{
		FirstName:     "Rohit",
		LastName:      "Kumar",
		Email:         "rohit@campus.edu",
		AdmissionYear: 2026,
		EntryType:     "regular",
		Program:       "btech",
	}
	stuBody, _ := json.Marshal(createStuPayload)
	stuReq := httptest.NewRequest(http.MethodPost, "/api/v1/users/students", bytes.NewReader(stuBody))
	stuRec := httptest.NewRecorder()
	userH.CreateStudent(stuRec, stuReq)

	if stuRec.Code != http.StatusCreated {
		t.Fatalf("Expected 201 Created for student, got %d", stuRec.Code)
	}

	var stuResp struct {
		User model.User `json:"user"`
	}
	if err := json.NewDecoder(stuRec.Body).Decode(&stuResp); err != nil {
		t.Fatalf("Failed to decode student response: %v", err)
	}

	handle := stuResp.User.CampusHandle
	if handle == "" {
		t.Fatalf("Expected generated campus handle, got empty")
	}
	if !stuResp.User.MustChangePassword {
		t.Errorf("Expected MustChangePassword to be true on initial user creation")
	}

	// 2. Login with incorrect password should fail
	badLoginPayload := LoginRequest{
		Identifier: handle,
		Password:   "wrongPassword123",
	}
	badBody, _ := json.Marshal(badLoginPayload)
	badReq := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(badBody))
	badRec := httptest.NewRecorder()
	authH.Login(badRec, badReq)
	if badRec.Code != http.StatusUnauthorized {
		t.Errorf("Expected 401 Unauthorized for incorrect password, got %d", badRec.Code)
	}

	// 3. Login with initial username as password (same on first creation) must succeed
	initLoginPayload := LoginRequest{
		Identifier: handle,
		Password:   handle, // Password is same as username!
	}
	initBody, _ := json.Marshal(initLoginPayload)
	initReq := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(initBody))
	initRec := httptest.NewRecorder()
	authH.Login(initRec, initReq)

	if initRec.Code != http.StatusOK {
		t.Fatalf("Expected 200 OK for initial login with username as password, got %d", initRec.Code)
	}

	var initResp LoginResponse
	_ = json.NewDecoder(initRec.Body).Decode(&initResp)
	if !initResp.User.MustChangePassword {
		t.Errorf("Expected MustChangePassword to be true on initial login")
	}

	// 4. Forced password change: invalid validations
	shortPassPayload := ChangePasswordRequest{
		Identifier:      handle,
		CurrentPassword: handle,
		NewPassword:     "123", // too short
	}
	spBody, _ := json.Marshal(shortPassPayload)
	spReq := httptest.NewRequest(http.MethodPost, "/api/v1/auth/change-password", bytes.NewReader(spBody))
	spRec := httptest.NewRecorder()
	authH.ChangePassword(spRec, spReq)
	if spRec.Code != http.StatusBadRequest {
		t.Errorf("Expected 400 Bad Request for short password, got %d", spRec.Code)
	}

	samePassPayload := ChangePasswordRequest{
		Identifier:      handle,
		CurrentPassword: handle,
		NewPassword:     handle, // same password
	}
	sameBody, _ := json.Marshal(samePassPayload)
	sameReq := httptest.NewRequest(http.MethodPost, "/api/v1/auth/change-password", bytes.NewReader(sameBody))
	sameRec := httptest.NewRecorder()
	authH.ChangePassword(sameRec, sameReq)
	if sameRec.Code != http.StatusBadRequest {
		t.Errorf("Expected 400 Bad Request for identical password, got %d", sameRec.Code)
	}

	wrongCurrentPayload := ChangePasswordRequest{
		Identifier:      handle,
		CurrentPassword: "incorrectCurrentPassword",
		NewPassword:     "brandNewStrongPass2026!",
	}
	wcBody, _ := json.Marshal(wrongCurrentPayload)
	wcReq := httptest.NewRequest(http.MethodPost, "/api/v1/auth/change-password", bytes.NewReader(wcBody))
	wcRec := httptest.NewRecorder()
	authH.ChangePassword(wcRec, wcReq)
	if wcRec.Code != http.StatusUnauthorized {
		t.Errorf("Expected 401 Unauthorized for wrong current password, got %d", wcRec.Code)
	}

	// 5. Successful password change
	validChangePayload := ChangePasswordRequest{
		Identifier:      handle,
		CurrentPassword: handle,
		NewPassword:     "brandNewStrongPass2026!",
	}
	vcBody, _ := json.Marshal(validChangePayload)
	vcReq := httptest.NewRequest(http.MethodPost, "/api/v1/auth/change-password", bytes.NewReader(vcBody))
	vcRec := httptest.NewRecorder()
	authH.ChangePassword(vcRec, vcReq)

	if vcRec.Code != http.StatusOK {
		t.Fatalf("Expected 200 OK for valid change password, got %d", vcRec.Code)
	}

	var changeResp ChangePasswordResponse
	_ = json.NewDecoder(vcRec.Body).Decode(&changeResp)
	if changeResp.User.MustChangePassword {
		t.Errorf("Expected MustChangePassword to be false after change password")
	}

	// 6. Old password no longer works
	oldLoginReq := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(initBody))
	oldLoginRec := httptest.NewRecorder()
	authH.Login(oldLoginRec, oldLoginReq)
	if oldLoginRec.Code != http.StatusUnauthorized {
		t.Errorf("Expected 401 Unauthorized when attempting to login with old username as password, got %d", oldLoginRec.Code)
	}

	// 7. Login with new password succeeds with MustChangePassword = false
	newLoginPayload := LoginRequest{
		Identifier: handle,
		Password:   "brandNewStrongPass2026!",
	}
	newBody, _ := json.Marshal(newLoginPayload)
	newReq := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(newBody))
	newRec := httptest.NewRecorder()
	authH.Login(newRec, newReq)

	if newRec.Code != http.StatusOK {
		t.Fatalf("Expected 200 OK for login with new password, got %d", newRec.Code)
	}
	var newResp LoginResponse
	_ = json.NewDecoder(newRec.Body).Decode(&newResp)
	if newResp.User.MustChangePassword {
		t.Errorf("Expected MustChangePassword to remain false on subsequent logins")
	}
}

func TestUserCreationWithCustomInitialPassword(t *testing.T) {
	idGen := idgen.NewIDService(nil)
	userH := NewUserHandler(idGen, nil)
	authH := NewAuthHandler(nil, userH)

	// 1. Create student with an explicit initial password
	customPass := "TempSecret#2026"
	createStuPayload := CreateStudentRequest{
		FirstName:       "Priya",
		LastName:        "Sharma",
		Email:           "priya.sharma@campus.edu",
		AdmissionYear:   2026,
		EntryType:       "regular",
		Program:         "btech",
		InitialPassword: customPass,
	}
	stuBody, _ := json.Marshal(createStuPayload)
	stuReq := httptest.NewRequest(http.MethodPost, "/api/v1/users/students", bytes.NewReader(stuBody))
	stuRec := httptest.NewRecorder()
	userH.CreateStudent(stuRec, stuReq)

	if stuRec.Code != http.StatusCreated {
		t.Fatalf("Expected 201 Created, got %d", stuRec.Code)
	}

	var stuResp struct {
		User            model.User `json:"user"`
		InitialPassword string     `json:"initial_password"`
	}
	if err := json.NewDecoder(stuRec.Body).Decode(&stuResp); err != nil {
		t.Fatalf("Failed to decode student response: %v", err)
	}

	if stuResp.InitialPassword != customPass {
		t.Errorf("Expected initial_password %q, got %q", customPass, stuResp.InitialPassword)
	}
	if !stuResp.User.MustChangePassword {
		t.Errorf("Expected MustChangePassword to be true on creation")
	}

	// 2. Login using the explicit initial password and institutional email
	loginPayload := LoginRequest{
		Identifier: "priya.sharma@campus.edu",
		Password:   customPass,
	}
	loginBody, _ := json.Marshal(loginPayload)
	loginReq := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(loginBody))
	loginRec := httptest.NewRecorder()
	authH.Login(loginRec, loginReq)

	if loginRec.Code != http.StatusOK {
		t.Fatalf("Expected 200 OK for login with custom initial password, got %d", loginRec.Code)
	}

	var loginResp LoginResponse
	_ = json.NewDecoder(loginRec.Body).Decode(&loginResp)
	if !loginResp.User.MustChangePassword {
		t.Errorf("Expected MustChangePassword to be true on first login")
	}

	// 3. User forces change password to permanent password
	permanentPass := "MyPermanentPass2026!"
	changePayload := ChangePasswordRequest{
		Identifier:      stuResp.User.CampusHandle,
		CurrentPassword: customPass,
		NewPassword:     permanentPass,
	}
	cpBody, _ := json.Marshal(changePayload)
	cpReq := httptest.NewRequest(http.MethodPost, "/api/v1/auth/change-password", bytes.NewReader(cpBody))
	cpRec := httptest.NewRecorder()
	authH.ChangePassword(cpRec, cpReq)

	if cpRec.Code != http.StatusOK {
		t.Fatalf("Expected 200 OK for changing password, got %d", cpRec.Code)
	}

	// 4. Temporary initial password must fail now
	oldLoginPayload := LoginRequest{
		Identifier: stuResp.User.CampusHandle,
		Password:   customPass,
	}
	oldLoginBody, _ := json.Marshal(oldLoginPayload)
	oldLoginReq := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(oldLoginBody))
	oldLoginRec := httptest.NewRecorder()
	authH.Login(oldLoginRec, oldLoginReq)

	if oldLoginRec.Code != http.StatusUnauthorized {
		t.Errorf("Expected 401 Unauthorized for old temporary password, got %d", oldLoginRec.Code)
	}

	// 5. Subsequent login with permanent password succeeds with MustChangePassword = false
	permLoginPayload := LoginRequest{
		Identifier: stuResp.User.CampusHandle,
		Password:   permanentPass,
	}
	permLoginBody, _ := json.Marshal(permLoginPayload)
	permLoginReq := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(permLoginBody))
	permLoginRec := httptest.NewRecorder()
	authH.Login(permLoginRec, permLoginReq)

	if permLoginRec.Code != http.StatusOK {
		t.Fatalf("Expected 200 OK for login with permanent password, got %d", permLoginRec.Code)
	}
	var permResp LoginResponse
	_ = json.NewDecoder(permLoginRec.Body).Decode(&permResp)
	if permResp.User.MustChangePassword {
		t.Errorf("Expected MustChangePassword to be false on subsequent login")
	}
}
