package handler

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

func TestPaymentHandler_Endpoints(t *testing.T) {
	feeSvc := service.NewFeeService(nil, nil)
	paySvc := service.NewPaymentService(feeSvc)
	h := NewPaymentHandler(paySvc)

	// 1. GET /api/v1/payments/config
	reqConfig := httptest.NewRequest(http.MethodGet, "/api/v1/payments/config", nil)
	wConfig := httptest.NewRecorder()
	h.HandleConfig(wConfig, reqConfig)

	if wConfig.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", wConfig.Code)
	}
	var cfg model.PaymentGatewayPublicConfig
	if err := json.NewDecoder(wConfig.Body).Decode(&cfg); err != nil {
		t.Fatalf("failed to decode config: %v", err)
	}
	if cfg.Provider != model.GatewayProviderSandbox {
		t.Fatalf("expected sandbox, got %s", cfg.Provider)
	}

	// 2. POST /api/v1/payments/order
	orderPayload := model.CreatePaymentOrderRequest{
		EntityType: "invoice",
		EntityID:   "inv-tuition-2026-sem3",
		StudentID:  "usr-harish_2025_l_btech_1",
		Amount:     12500,
	}
	rawOrder, _ := json.Marshal(orderPayload)
	reqOrder := httptest.NewRequest(http.MethodPost, "/api/v1/payments/order", bytes.NewReader(rawOrder))
	wOrder := httptest.NewRecorder()
	h.HandleCreateOrder(wOrder, reqOrder)

	if wOrder.Code != http.StatusCreated {
		t.Fatalf("expected 201 created, got %d: %s", wOrder.Code, wOrder.Body.String())
	}
	var createdOrder model.PaymentOrder
	if err := json.NewDecoder(wOrder.Body).Decode(&createdOrder); err != nil {
		t.Fatalf("failed to decode created order: %v", err)
	}
	if createdOrder.OrderID == "" || createdOrder.Amount != 12500 {
		t.Fatalf("invalid created order data: %+v", createdOrder)
	}

	// 3. POST /api/v1/payments/verify
	verifyPayload := model.VerifyPaymentRequest{
		OrderID:        createdOrder.OrderID,
		PaymentID:      "pay_test_endpoint_8819",
		PaymentMethod:  model.PaymentMethodUPI,
		TransactionRef: "UPI/REF/9912",
	}
	rawVerify, _ := json.Marshal(verifyPayload)
	reqVerify := httptest.NewRequest(http.MethodPost, "/api/v1/payments/verify", bytes.NewReader(rawVerify))
	wVerify := httptest.NewRecorder()
	h.HandleVerifyPayment(wVerify, reqVerify)

	if wVerify.Code != http.StatusOK {
		t.Fatalf("expected 200 verify, got %d: %s", wVerify.Code, wVerify.Body.String())
	}
	var verifyResp model.VerifyPaymentResponse
	if err := json.NewDecoder(wVerify.Body).Decode(&verifyResp); err != nil {
		t.Fatalf("failed to decode verify response: %v", err)
	}
	if !verifyResp.Success || verifyResp.Receipt == nil {
		t.Fatalf("expected success verify response: %+v", verifyResp)
	}

	// 4. Method not allowed tests
	reqBad := httptest.NewRequest(http.MethodDelete, "/api/v1/payments/config", nil)
	wBad := httptest.NewRecorder()
	h.HandleConfig(wBad, reqBad)
	if wBad.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405, got %d", wBad.Code)
	}
}
