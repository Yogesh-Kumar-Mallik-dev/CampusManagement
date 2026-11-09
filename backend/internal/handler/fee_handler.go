package handler

import (
	"encoding/json"
	"fmt"
	"net/http"

	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

// FeeHandler routes incoming HTTP traffic to FeeServiceInterface
type FeeHandler struct {
	feeService service.FeeServiceInterface
}

// NewFeeHandler constructs a new FeeHandler
func NewFeeHandler(svc service.FeeServiceInterface) *FeeHandler {
	return &FeeHandler{feeService: svc}
}

// HandleSummary handles GET /api/v1/fees/summary
func (h *FeeHandler) HandleSummary(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	studentID := r.URL.Query().Get("student_id")
	summary, err := h.feeService.GetFeeSummary(r.Context(), studentID)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(summary)
}

// HandleInvoices handles GET and POST /api/v1/fees/invoices
func (h *FeeHandler) HandleInvoices(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	switch r.Method {
	case http.MethodGet:
		id := r.URL.Query().Get("id")
		if id != "" {
			inv, err := h.feeService.GetInvoiceByID(r.Context(), id)
			if err != nil {
				http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusNotFound)
				return
			}
			_ = json.NewEncoder(w).Encode(inv)
			return
		}

		studentID := r.URL.Query().Get("student_id")
		status := r.URL.Query().Get("status")
		invoices, err := h.feeService.GetInvoices(r.Context(), studentID, status)
		if err != nil {
			http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
			return
		}
		_ = json.NewEncoder(w).Encode(invoices)

	case http.MethodPost:
		var inv model.FeeInvoice
		if err := json.NewDecoder(r.Body).Decode(&inv); err != nil {
			http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
			return
		}

		created, err := h.feeService.CreateInvoice(r.Context(), inv)
		if err != nil {
			http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
			return
		}

		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(created)

	default:
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
	}
}

// HandlePayInvoice handles POST /api/v1/fees/pay
func (h *FeeHandler) HandlePayInvoice(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req model.PayInvoiceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
		return
	}

	payment, receipt, err := h.feeService.PayInvoice(r.Context(), req)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"payment": payment,
		"receipt": receipt,
	})
}

// HandleFines handles GET and POST /api/v1/fees/fines
func (h *FeeHandler) HandleFines(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	switch r.Method {
	case http.MethodGet:
		studentID := r.URL.Query().Get("student_id")
		status := r.URL.Query().Get("status")
		fines, err := h.feeService.GetFines(r.Context(), studentID, status)
		if err != nil {
			http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
			return
		}
		_ = json.NewEncoder(w).Encode(fines)

	case http.MethodPost:
		var fine model.FineRecord
		if err := json.NewDecoder(r.Body).Decode(&fine); err != nil {
			http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
			return
		}

		created, err := h.feeService.IssueFine(r.Context(), fine)
		if err != nil {
			http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
			return
		}

		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(created)

	default:
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
	}
}

// HandlePayFine handles POST /api/v1/fees/fines/pay
func (h *FeeHandler) HandlePayFine(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req model.PayFineRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
		return
	}

	payment, receipt, err := h.feeService.PayFine(r.Context(), req)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"payment": payment,
		"receipt": receipt,
	})
}

// HandleAppealFine handles POST /api/v1/fees/fines/appeal
func (h *FeeHandler) HandleAppealFine(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		FineID string `json:"fine_id"`
		Reason string `json:"reason"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
		return
	}

	fine, err := h.feeService.AppealFine(r.Context(), req.FineID, req.Reason)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(fine)
}

// HandleWaiveFine handles POST /api/v1/fees/fines/waive
func (h *FeeHandler) HandleWaiveFine(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		FineID   string `json:"fine_id"`
		WaivedBy string `json:"waived_by"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
		return
	}

	fine, err := h.feeService.WaiveFine(r.Context(), req.FineID, req.WaivedBy)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(fine)
}

// HandlePayments handles GET /api/v1/fees/payments
func (h *FeeHandler) HandlePayments(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	studentID := r.URL.Query().Get("student_id")
	payments, err := h.feeService.GetPaymentRecords(r.Context(), studentID)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(payments)
}

// HandleReceipt handles GET /api/v1/fees/receipt
func (h *FeeHandler) HandleReceipt(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	number := r.URL.Query().Get("number")
	if number == "" {
		http.Error(w, `{"error":"receipt number is required"}`, http.StatusBadRequest)
		return
	}

	receipt, err := h.feeService.GetReceipt(r.Context(), number)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(receipt)
}

// HandleInvoicePDF handles GET /api/v1/fees/invoices/pdf?id={id}
func (h *FeeHandler) HandleInvoicePDF(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	id := r.URL.Query().Get("id")
	if id == "" {
		http.Error(w, `{"error":"invoice id is required"}`, http.StatusBadRequest)
		return
	}

	pdfBytes, filename, err := h.feeService.GenerateInvoicePDF(r.Context(), id)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/pdf")
	w.Header().Set("Content-Disposition", fmt.Sprintf(`attachment; filename="%s"`, filename))
	w.Header().Set("Content-Length", fmt.Sprintf("%d", len(pdfBytes)))
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(pdfBytes)
}
