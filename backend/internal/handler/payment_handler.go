package handler

import (
	"encoding/json"
	"io"
	"net/http"

	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

// PaymentHandler routes payment gateway checkout and settlement requests
type PaymentHandler struct {
	paymentService service.PaymentServiceInterface
}

// NewPaymentHandler constructs a new PaymentHandler
func NewPaymentHandler(svc service.PaymentServiceInterface) *PaymentHandler {
	return &PaymentHandler{paymentService: svc}
}

// HandleConfig handles GET /api/v1/payments/config
func (h *PaymentHandler) HandleConfig(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	config := h.paymentService.GetPublicConfig(r.Context())
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(config)
}

// HandleCreateOrder handles POST /api/v1/payments/order
func (h *PaymentHandler) HandleCreateOrder(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req model.CreatePaymentOrderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid JSON request payload"}`, http.StatusBadRequest)
		return
	}

	order, err := h.paymentService.CreateOrder(r.Context(), req)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(order)
}

// HandleVerifyPayment handles POST /api/v1/payments/verify
func (h *PaymentHandler) HandleVerifyPayment(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req model.VerifyPaymentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid JSON request payload"}`, http.StatusBadRequest)
		return
	}

	payment, receipt, err := h.paymentService.VerifyAndCapture(r.Context(), req)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}

	resp := model.VerifyPaymentResponse{
		Success:        true,
		Payment:        payment,
		Receipt:        receipt,
		Message:        "Payment captured and applied to ledger successfully",
		TransactionRef: payment.TransactionRef,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(resp)
}

// HandleWebhook handles POST /api/v1/payments/webhook
func (h *PaymentHandler) HandleWebhook(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	sig := r.Header.Get("X-Razorpay-Signature")
	if sig == "" {
		sig = r.Header.Get("X-Webhook-Signature")
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, `{"error":"cannot read webhook body"}`, http.StatusBadRequest)
		return
	}

	if err := h.paymentService.ProcessWebhook(r.Context(), body, sig); err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]string{"status": "received"})
}
