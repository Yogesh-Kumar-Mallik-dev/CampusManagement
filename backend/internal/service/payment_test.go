package service

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"os"
	"testing"

	"campus/backend/internal/model"
)

func TestPaymentService_SandboxFlow(t *testing.T) {
	feeSvc := NewFeeService(nil, nil)
	paySvc := NewPaymentService(feeSvc)

	ctx := context.Background()

	// 1. Check Public Config
	cfg := paySvc.GetPublicConfig(ctx)
	if cfg.Provider != model.GatewayProviderSandbox {
		t.Fatalf("expected sandbox provider, got %s", cfg.Provider)
	}
	if cfg.MerchantVPA == "" {
		t.Fatal("expected merchant VPA to be set")
	}
	if len(cfg.SupportedMethods) < 4 {
		t.Fatalf("expected at least 4 payment methods, got %d", len(cfg.SupportedMethods))
	}

	// 2. Create Order for Tuition Invoice
	req := model.CreatePaymentOrderRequest{
		EntityType: "invoice",
		EntityID:   "inv-tuition-2026-sem3",
		StudentID:  "usr-harish_2025_l_btech_1",
		Amount:     10000,
	}

	order, err := paySvc.CreateOrder(ctx, req)
	if err != nil {
		t.Fatalf("failed to create payment order: %v", err)
	}

	if order.OrderID == "" {
		t.Fatal("expected non-empty order ID")
	}
	if order.Amount != 10000 {
		t.Fatalf("expected amount 10000, got %f", order.Amount)
	}
	if order.VirtualAccount == nil || order.VirtualAccount.AccountNumber == "" {
		t.Fatal("expected virtual account for NEFT/RTGS")
	}
	if order.UPILink == "" {
		t.Fatal("expected UPI deep-link to be populated")
	}

	// 3. Verify and Capture
	verifyReq := model.VerifyPaymentRequest{
		OrderID:        order.OrderID,
		PaymentID:      "pay_mock_sandbox_12345",
		PaymentMethod:  model.PaymentMethodUPI,
		TransactionRef: "UPI/TXN/998877",
	}

	payment, receipt, err := paySvc.VerifyAndCapture(ctx, verifyReq)
	if err != nil {
		t.Fatalf("failed to verify payment: %v", err)
	}

	if payment == nil || receipt == nil {
		t.Fatal("expected payment and receipt to be non-nil")
	}
	if receipt.ReceiptNumber == "" {
		t.Fatal("expected receipt number to be generated")
	}
	if receipt.Amount != 10000 {
		t.Fatalf("expected receipt amount 10000, got %f", receipt.Amount)
	}

	// 4. Double capture should fail
	_, _, err = paySvc.VerifyAndCapture(ctx, verifyReq)
	if err == nil {
		t.Fatal("expected error on re-settling an already paid order")
	}
}

func TestPaymentService_RazorpayHMACVerification(t *testing.T) {
	_ = os.Setenv("PAYMENT_GATEWAY_PROVIDER", "razorpay")
	_ = os.Setenv("PAYMENT_GATEWAY_KEY_SECRET", "super_secret_key_12345")
	defer func() {
		_ = os.Unsetenv("PAYMENT_GATEWAY_PROVIDER")
		_ = os.Unsetenv("PAYMENT_GATEWAY_KEY_SECRET")
	}()

	feeSvc := NewFeeService(nil, nil)
	paySvc := NewPaymentService(feeSvc)
	ctx := context.Background()

	order, err := paySvc.CreateOrder(ctx, model.CreatePaymentOrderRequest{
		EntityType: "invoice",
		EntityID:   "inv-tuition-2026-sem3",
		StudentID:  "usr-harish_2025_l_btech_1",
		Amount:     5000,
	})
	if err != nil {
		t.Fatalf("failed to create order: %v", err)
	}

	paymentID := "pay_rzp_mock_991823"

	// Invalid signature should fail
	_, _, err = paySvc.VerifyAndCapture(ctx, model.VerifyPaymentRequest{
		OrderID:       order.OrderID,
		PaymentID:     paymentID,
		PaymentMethod: model.PaymentMethodDebitCard,
		Signature:     "invalid_hex_signature",
	})
	if err == nil {
		t.Fatal("expected failure for invalid razorpay signature")
	}

	// Valid HMAC signature
	msg := order.GatewayOrderID + "|" + paymentID
	h := hmac.New(sha256.New, []byte("super_secret_key_12345"))
	h.Write([]byte(msg))
	validSig := hex.EncodeToString(h.Sum(nil))

	pay, rcp, err := paySvc.VerifyAndCapture(ctx, model.VerifyPaymentRequest{
		OrderID:       order.OrderID,
		PaymentID:     paymentID,
		PaymentMethod: model.PaymentMethodDebitCard,
		Signature:     validSig,
	})
	if err != nil {
		t.Fatalf("expected valid signature to succeed: %v", err)
	}
	if pay == nil || rcp == nil {
		t.Fatal("expected non-nil payment and receipt")
	}
}

func TestPaymentService_FineSettlementOrder(t *testing.T) {
	feeSvc := NewFeeService(nil, nil)
	paySvc := NewPaymentService(feeSvc)
	ctx := context.Background()

	// Create fine order
	order, err := paySvc.CreateOrder(ctx, model.CreatePaymentOrderRequest{
		EntityType: "fine",
		EntityID:   "fine-lib-01",
		StudentID:  "usr-harish_2025_l_btech_1",
		Amount:     150,
	})
	if err != nil {
		t.Fatalf("failed to create fine order: %v", err)
	}

	if order.Amount != 150 {
		t.Fatalf("expected 150, got %f", order.Amount)
	}

	// Verify and capture
	pay, rcp, err := paySvc.VerifyAndCapture(ctx, model.VerifyPaymentRequest{
		OrderID:       order.OrderID,
		PaymentID:     "pay_fine_settle_01",
		PaymentMethod: model.PaymentMethodUPI,
	})
	if err != nil {
		t.Fatalf("failed to settle fine order: %v", err)
	}
	if pay.Amount != 150 || rcp.Amount != 150 {
		t.Fatalf("expected 150 settlement, got pay=%f rcp=%f", pay.Amount, rcp.Amount)
	}
}
