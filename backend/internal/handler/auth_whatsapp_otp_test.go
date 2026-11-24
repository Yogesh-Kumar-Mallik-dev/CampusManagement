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

func TestWhatsAppOTPFirstLoginAndDualChannelReset(t *testing.T) {
	idGen := idgen.NewIDService(nil)
	userH := NewUserHandler(idGen, nil)
	authH := NewAuthHandler(nil, userH)

	// 1. Create a student user with WhatsApp Phone
	createStuPayload := CreateStudentRequest{
		FirstName:     "Sanya",
		LastName:      "Malhotra",
		Email:         "sanya@campus.edu",
		Phone:         "+919812345678",
		AdmissionYear: 2026,
		EntryType:     "regular",
		Program:       "btech",
	}
	body, _ := json.Marshal(createStuPayload)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/users/students", bytes.NewReader(body))
	rec := httptest.NewRecorder()
	userH.CreateStudent(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("Failed to create student: status %d", rec.Code)
	}

	var stuResp struct {
		User model.User `json:"user"`
	}
	_ = json.NewDecoder(rec.Body).Decode(&stuResp)
	handle := stuResp.User.CampusHandle
	if handle == "" {
		t.Fatalf("Expected campus handle")
	}

	// 2. Request First Login WhatsApp OTP
	otpReqPayload := model.RequestOTPRequest{
		Identifier: handle,
		Purpose:    "first_login",
	}
	body, _ = json.Marshal(otpReqPayload)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/auth/first-login/request-otp", bytes.NewReader(body))
	rec = httptest.NewRecorder()
	authH.RequestFirstLoginOTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("Expected status 200 for OTP request, got %d: %s", rec.Code, rec.Body.String())
	}

	var otpResp model.RequestOTPResponse
	_ = json.NewDecoder(rec.Body).Decode(&otpResp)
	if otpResp.TargetPhone == "" {
		t.Errorf("Expected masked target phone")
	}

	// 3. First Login: verify OTP, establish new password and security question
	firstLoginPayload := model.FirstLoginSetPasswordRequest{
		Identifier:       handle,
		OTPCode:          "123456", // mock mode accepted code
		NewPassword:      "MySecurePass2026#",
		SecurityQuestion: "What was your high school name?",
		SecurityAnswer:   "Delhi Public School",
	}
	body, _ = json.Marshal(firstLoginPayload)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/auth/first-login/verify-and-set-password", bytes.NewReader(body))
	rec = httptest.NewRecorder()
	authH.FirstLoginSetPassword(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("Expected status 200 for first login set password, got %d: %s", rec.Code, rec.Body.String())
	}

	var loginResp LoginResponse
	_ = json.NewDecoder(rec.Body).Decode(&loginResp)
	if loginResp.User.MustChangePassword {
		t.Errorf("Expected MustChangePassword to be false after first login setup")
	}
	if loginResp.User.IsFirstLogin {
		t.Errorf("Expected IsFirstLogin to be false after first login setup")
	}
	if loginResp.User.SecurityQuestion != "What was your high school name?" {
		t.Errorf("Expected security question stored, got %s", loginResp.User.SecurityQuestion)
	}

	// 4. Verify login with newly established permanent password
	loginPayload := LoginRequest{
		Identifier: handle,
		Password:   "MySecurePass2026#",
	}
	body, _ = json.Marshal(loginPayload)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(body))
	rec = httptest.NewRecorder()
	authH.Login(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("Expected login with new password to succeed, got %d", rec.Code)
	}

	// -------------------------------------------------------------
	// 5. Channel A: Password Reset via WhatsApp OTP + Security Question
	// -------------------------------------------------------------
	resetOtpPayload := model.RequestOTPRequest{
		Identifier: handle,
		Purpose:    "password_reset",
	}
	body, _ = json.Marshal(resetOtpPayload)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/auth/reset-password/request-otp", bytes.NewReader(body))
	rec = httptest.NewRecorder()
	authH.RequestResetPasswordOTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("Expected status 200 for reset OTP request, got %d", rec.Code)
	}

	// Query Security Question Prompt
	req = httptest.NewRequest(http.MethodGet, "/api/v1/auth/reset-password/security-question?identifier="+handle, nil)
	rec = httptest.NewRecorder()
	authH.GetSecurityQuestionPrompt(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("Expected status 200 for security question prompt, got %d", rec.Code)
	}
	var sqResp map[string]interface{}
	_ = json.NewDecoder(rec.Body).Decode(&sqResp)
	if sqResp["security_question"] != "What was your high school name?" {
		t.Errorf("Expected security question in prompt, got %v", sqResp["security_question"])
	}

	// Incorrect security answer fails
	badResetPayload := model.ResetPasswordWithQuestionRequest{
		Identifier:     handle,
		OTPCode:        "123456",
		SecurityAnswer: "Wrong School",
		NewPassword:    "BrandNewPass2027#",
	}
	body, _ = json.Marshal(badResetPayload)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/auth/reset-password/verify-otp-and-question", bytes.NewReader(body))
	rec = httptest.NewRecorder()
	authH.ResetPasswordWithSecurityQuestion(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Errorf("Expected 401 for wrong security answer, got %d", rec.Code)
	}

	// Correct security answer succeeds
	goodResetPayload := model.ResetPasswordWithQuestionRequest{
		Identifier:     handle,
		OTPCode:        "123456",
		SecurityAnswer: "Delhi Public School",
		NewPassword:    "BrandNewPass2027#",
	}
	body, _ = json.Marshal(goodResetPayload)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/auth/reset-password/verify-otp-and-question", bytes.NewReader(body))
	rec = httptest.NewRecorder()
	authH.ResetPasswordWithSecurityQuestion(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("Expected 200 for correct security reset, got %d: %s", rec.Code, rec.Body.String())
	}

	// -------------------------------------------------------------
	// 6. Channel B: Password Reset via WhatsApp OTP + Admin Escalation
	// -------------------------------------------------------------
	// Submit escalation ticket
	escReqPayload := model.CreateResetEscalationRequest{
		Identifier: handle,
		OTPCode:    "123456",
		Reason:     "Forgot security question answer; need IT administrator verification",
	}
	body, _ = json.Marshal(escReqPayload)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/auth/reset-password/escalate-to-admin", bytes.NewReader(body))
	rec = httptest.NewRecorder()
	authH.CreateResetEscalation(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("Expected 200 for escalation creation, got %d: %s", rec.Code, rec.Body.String())
	}
	var escResp map[string]interface{}
	_ = json.NewDecoder(rec.Body).Decode(&escResp)
	ticketNum, _ := escResp["ticket_number"].(string)
	if ticketNum == "" {
		t.Fatalf("Expected ticket number in escalation response")
	}

	// Admin lists escalations
	req = httptest.NewRequest(http.MethodGet, "/api/v1/auth/reset-password/escalations", nil)
	rec = httptest.NewRecorder()
	authH.ListResetEscalations(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("Expected 200 for admin listing escalations, got %d", rec.Code)
	}

	// Admin approves escalation and generates token
	adminApprovePayload := model.AdminResolveEscalationRequest{
		TicketNumber: ticketNum,
		Action:       "approve",
		AdminUserID:  "usr-campus_admin",
	}
	body, _ = json.Marshal(adminApprovePayload)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/auth/reset-password/admin-resolve-escalation", bytes.NewReader(body))
	rec = httptest.NewRecorder()
	authH.AdminResolveEscalation(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("Expected 200 for admin approval, got %d: %s", rec.Code, rec.Body.String())
	}
	var adminResolveResp model.AdminResolveEscalationResponse
	_ = json.NewDecoder(rec.Body).Decode(&adminResolveResp)
	adminToken := adminResolveResp.AdminToken
	if len(adminToken) != 6 {
		t.Fatalf("Expected 6-digit admin token, got %s", adminToken)
	}

	// User completes password reset with WhatsApp OTP + Admin Token
	tokenResetPayload := model.ResetPasswordWithAdminTokenRequest{
		Identifier:  handle,
		OTPCode:     "123456",
		AdminToken:  adminToken,
		NewPassword: "EscalationPass2027!",
	}
	body, _ = json.Marshal(tokenResetPayload)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/auth/reset-password/verify-otp-and-admin-token", bytes.NewReader(body))
	rec = httptest.NewRecorder()
	authH.ResetPasswordWithAdminToken(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("Expected 200 for admin token reset, got %d: %s", rec.Code, rec.Body.String())
	}

	// Final verification: login with new escalated password
	loginFinalPayload := LoginRequest{
		Identifier: handle,
		Password:   "EscalationPass2027!",
	}
	body, _ = json.Marshal(loginFinalPayload)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(body))
	rec = httptest.NewRecorder()
	authH.Login(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("Expected login with escalated password to succeed, got %d", rec.Code)
	}
}
