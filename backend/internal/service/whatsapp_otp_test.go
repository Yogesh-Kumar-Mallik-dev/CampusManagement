package service

import (
	"testing"
)

func TestWhatsAppOTPServiceFlow(t *testing.T) {
	svc := NewWhatsAppOTPService()

	// 1. Generate OTP
	code, err := svc.GenerateAndSendOTP("first_login", "student_1", "+919876543210")
	if err != nil {
		t.Fatalf("Failed to generate OTP: %v", err)
	}
	if len(code) != 6 {
		t.Errorf("Expected 6-digit OTP code, got %s", code)
	}

	// 2. Cooldown check
	canResend, remaining := svc.CanResend("first_login", "student_1")
	if canResend {
		t.Errorf("Expected resend cooldown to be active")
	}
	if remaining <= 0 {
		t.Errorf("Expected positive cooldown remaining seconds")
	}

	// 3. Second immediate request fails
	_, err = svc.GenerateAndSendOTP("first_login", "student_1", "+919876543210")
	if err == nil {
		t.Errorf("Expected error requesting OTP during cooldown")
	}

	// 4. Verification with wrong code
	if svc.VerifyOTP("first_login", "student_1", "000000") {
		t.Errorf("Expected wrong code verification to fail")
	}

	// 5. Verification with right code
	if !svc.VerifyOTP("first_login", "student_1", code) {
		t.Errorf("Expected verification with generated code to succeed")
	}

	// 6. Code is single-use: subsequent verification fails
	if svc.VerifyOTP("first_login", "student_1", code) {
		t.Errorf("Expected replay verification to fail")
	}
}

func TestSecurityAnswerHashing(t *testing.T) {
	answer := "  St. Mary's High School  "
	hash := HashSecurityAnswer(answer)

	if !VerifySecurityAnswer("st. mary's high school", hash) {
		t.Errorf("Expected case-insensitive, trimmed verification to pass")
	}
	if !VerifySecurityAnswer("St. Mary's High School", hash) {
		t.Errorf("Expected original case verification to pass")
	}
	if VerifySecurityAnswer("Delhi Public School", hash) {
		t.Errorf("Expected wrong answer verification to fail")
	}
	if VerifySecurityAnswer("   ", hash) || VerifySecurityAnswer("answer", "") {
		t.Errorf("Expected empty answer or empty hash to fail")
	}
}

func TestWhatsAppOTPServiceRemainingEdges(t *testing.T) {
	svc := NewWhatsAppOTPService()

	if rem := svc.GetRemainingSeconds("first_login", "unknown_user"); rem != 0 {
		t.Fatalf("expected 0 remaining seconds for unknown user, got %d", rem)
	}

	code, err := svc.GenerateAndSendOTP("password_reset", "user_2", "+919999988888")
	if err != nil {
		t.Fatalf("GenerateAndSendOTP failed: %v", err)
	}
	if rem := svc.GetRemainingSeconds("password_reset", "user_2"); rem <= 0 {
		t.Fatalf("expected positive remaining seconds, got %d", rem)
	}

	// Exhaust attempts (3 attempts)
	for i := 0; i < OTPMaxAttempts; i++ {
		if svc.VerifyOTP("password_reset", "user_2", "999999") {
			t.Fatal("expected wrong code to fail")
		}
	}
	// Even the valid code should now fail because max attempts exceeded and entry deleted
	if svc.VerifyOTP("password_reset", "user_2", code) {
		t.Fatal("expected verification to fail after max attempts")
	}

	// Non-mock dispatch branch
	t.Setenv("WHATSAPP_API_TOKEN", "live_tok")
	t.Setenv("WHATSAPP_PHONE_NUMBER_ID", "12345")
	liveSvc := NewWhatsAppOTPService()
	if _, err := liveSvc.GenerateAndSendOTP("first_login", "user_live", "+919999977777"); err != nil {
		t.Fatalf("live dispatch branch failed: %v", err)
	}
}
