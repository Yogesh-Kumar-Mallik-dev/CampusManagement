package handler

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

func TestFeeHandlerEndpoints(t *testing.T) {
	feeSvc := service.NewFeeService(nil, nil)
	feeH := NewFeeHandler(feeSvc)

	studentID := "usr-harish_2025_l_btech_1"

	// 1. HandleSummary
	reqSummary := httptest.NewRequest(http.MethodGet, "/api/v1/fees/summary?student_id="+studentID, nil)
	rrSummary := httptest.NewRecorder()
	feeH.HandleSummary(rrSummary, reqSummary)
	if rrSummary.Code != http.StatusOK {
		t.Fatalf("expected 200 from HandleSummary, got %d", rrSummary.Code)
	}

	reqSummBad := httptest.NewRequest(http.MethodPost, "/api/v1/fees/summary", nil)
	rrSummBad := httptest.NewRecorder()
	feeH.HandleSummary(rrSummBad, reqSummBad)
	if rrSummBad.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 from HandleSummary POST, got %d", rrSummBad.Code)
	}

	// 2. HandleInvoices (GET list, GET by ID, POST create, invalid methods/json)
	reqInvList := httptest.NewRequest(http.MethodGet, "/api/v1/fees/invoices?student_id="+studentID, nil)
	rrInvList := httptest.NewRecorder()
	feeH.HandleInvoices(rrInvList, reqInvList)
	if rrInvList.Code != http.StatusOK {
		t.Fatalf("expected 200 from HandleInvoices list, got %d", rrInvList.Code)
	}

	var invoices []model.FeeInvoice
	_ = json.Unmarshal(rrInvList.Body.Bytes(), &invoices)
	if len(invoices) == 0 {
		t.Fatalf("expected invoices in list")
	}

	// GET single invoice by id
	reqInvSingle := httptest.NewRequest(http.MethodGet, "/api/v1/fees/invoices?id="+invoices[0].ID, nil)
	rrInvSingle := httptest.NewRecorder()
	feeH.HandleInvoices(rrInvSingle, reqInvSingle)
	if rrInvSingle.Code != http.StatusOK {
		t.Fatalf("expected 200 from HandleInvoices single, got %d", rrInvSingle.Code)
	}

	reqInvMissing := httptest.NewRequest(http.MethodGet, "/api/v1/fees/invoices?id=missing-inv", nil)
	rrInvMissing := httptest.NewRecorder()
	feeH.HandleInvoices(rrInvMissing, reqInvMissing)
	if rrInvMissing.Code != http.StatusNotFound {
		t.Fatalf("expected 404 from HandleInvoices missing, got %d", rrInvMissing.Code)
	}

	// POST valid invoice
	newInvPayload := map[string]interface{}{
		"student_id":   studentID,
		"student_name": "Harish Kumar",
		"title":        "Laboratory Equipment & Consumables Fee",
		"total_amount": 5000,
		"fee_type":     "laboratory",
		"due_date":     time.Now().Add(20 * 24 * time.Hour).Format(time.RFC3339),
	}
	body, _ := json.Marshal(newInvPayload)
	reqInvPost := httptest.NewRequest(http.MethodPost, "/api/v1/fees/invoices", bytes.NewReader(body))
	rrInvPost := httptest.NewRecorder()
	feeH.HandleInvoices(rrInvPost, reqInvPost)
	if rrInvPost.Code != http.StatusCreated {
		t.Fatalf("expected 201 from HandleInvoices POST, got %d", rrInvPost.Code)
	}

	// POST invalid JSON
	reqInvBad := httptest.NewRequest(http.MethodPost, "/api/v1/fees/invoices", bytes.NewReader([]byte("{invalid")))
	rrInvBad := httptest.NewRecorder()
	feeH.HandleInvoices(rrInvBad, reqInvBad)
	if rrInvBad.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from HandleInvoices invalid json, got %d", rrInvBad.Code)
	}

	// Method Not Allowed
	reqInvDel := httptest.NewRequest(http.MethodDelete, "/api/v1/fees/invoices", nil)
	rrInvDel := httptest.NewRecorder()
	feeH.HandleInvoices(rrInvDel, reqInvDel)
	if rrInvDel.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 from HandleInvoices DELETE, got %d", rrInvDel.Code)
	}

	// 3. HandlePayInvoice
	var targetInvoice model.FeeInvoice
	for _, inv := range invoices {
		if inv.DueAmount > 0 {
			targetInvoice = inv
			break
		}
	}
	if targetInvoice.ID == "" {
		t.Fatal("expected at least one invoice with due balance")
	}

	payReq := map[string]interface{}{
		"invoice_id":     targetInvoice.ID,
		"student_id":     studentID,
		"amount":         1000,
		"payment_method": "upi",
	}
	payBody, _ := json.Marshal(payReq)
	reqPay := httptest.NewRequest(http.MethodPost, "/api/v1/fees/pay", bytes.NewReader(payBody))
	rrPay := httptest.NewRecorder()
	feeH.HandlePayInvoice(rrPay, reqPay)
	if rrPay.Code != http.StatusOK {
		t.Fatalf("expected 200 from HandlePayInvoice, got %d", rrPay.Code)
	}

	reqPayBadMethod := httptest.NewRequest(http.MethodGet, "/api/v1/fees/pay", nil)
	rrPayBadMethod := httptest.NewRecorder()
	feeH.HandlePayInvoice(rrPayBadMethod, reqPayBadMethod)
	if rrPayBadMethod.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 from HandlePayInvoice GET, got %d", rrPayBadMethod.Code)
	}

	reqPayBadJSON := httptest.NewRequest(http.MethodPost, "/api/v1/fees/pay", bytes.NewReader([]byte("{invalid")))
	rrPayBadJSON := httptest.NewRecorder()
	feeH.HandlePayInvoice(rrPayBadJSON, reqPayBadJSON)
	if rrPayBadJSON.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from HandlePayInvoice bad JSON, got %d", rrPayBadJSON.Code)
	}

	// 4. HandleFines (GET list, POST issue, invalid method/json)
	reqFinesList := httptest.NewRequest(http.MethodGet, "/api/v1/fees/fines?student_id="+studentID, nil)
	rrFinesList := httptest.NewRecorder()
	feeH.HandleFines(rrFinesList, reqFinesList)
	if rrFinesList.Code != http.StatusOK {
		t.Fatalf("expected 200 from HandleFines GET, got %d", rrFinesList.Code)
	}

	var fines []model.FineRecord
	_ = json.Unmarshal(rrFinesList.Body.Bytes(), &fines)

	finePostPayload := map[string]interface{}{
		"student_id":   studentID,
		"student_name": "Harish Kumar",
		"category":     "library",
		"reason":       "Late return of textbook",
		"amount":       100,
	}
	fineBody, _ := json.Marshal(finePostPayload)
	reqFinePost := httptest.NewRequest(http.MethodPost, "/api/v1/fees/fines", bytes.NewReader(fineBody))
	rrFinePost := httptest.NewRecorder()
	feeH.HandleFines(rrFinePost, reqFinePost)
	if rrFinePost.Code != http.StatusCreated {
		t.Fatalf("expected 201 from HandleFines POST, got %d", rrFinePost.Code)
	}

	var createdFine model.FineRecord
	_ = json.Unmarshal(rrFinePost.Body.Bytes(), &createdFine)

	// 5. HandlePayFine
	reqPayFine := httptest.NewRequest(http.MethodPost, "/api/v1/fees/fines/pay", bytes.NewReader([]byte(`{
		"fine_id": "`+createdFine.ID+`",
		"student_id": "`+studentID+`",
		"payment_method": "net_banking"
	}`)))
	rrPayFine := httptest.NewRecorder()
	feeH.HandlePayFine(rrPayFine, reqPayFine)
	if rrPayFine.Code != http.StatusOK {
		t.Fatalf("expected 200 from HandlePayFine, got %d", rrPayFine.Code)
	}

	// 6. HandleAppealFine
	appealFinePayload, _ := json.Marshal(map[string]string{
		"fine_id": fines[0].ID,
		"reason":  "Medical emergency precluded on-time return",
	})
	reqAppeal := httptest.NewRequest(http.MethodPost, "/api/v1/fees/fines/appeal", bytes.NewReader(appealFinePayload))
	rrAppeal := httptest.NewRecorder()
	feeH.HandleAppealFine(rrAppeal, reqAppeal)
	if rrAppeal.Code != http.StatusOK && rrAppeal.Code != http.StatusBadRequest {
		t.Fatalf("unexpected code from HandleAppealFine: %d", rrAppeal.Code)
	}

	// 7. HandleWaiveFine
	waivePayload, _ := json.Marshal(map[string]string{
		"fine_id":   fines[0].ID,
		"waived_by": "Dean of Student Affairs",
	})
	reqWaive := httptest.NewRequest(http.MethodPost, "/api/v1/fees/fines/waive", bytes.NewReader(waivePayload))
	rrWaive := httptest.NewRecorder()
	feeH.HandleWaiveFine(rrWaive, reqWaive)
	if rrWaive.Code != http.StatusOK && rrWaive.Code != http.StatusBadRequest {
		t.Fatalf("unexpected code from HandleWaiveFine: %d", rrWaive.Code)
	}

	// 8. HandlePayments & HandleReceipt
	reqPayments := httptest.NewRequest(http.MethodGet, "/api/v1/fees/payments?student_id="+studentID, nil)
	rrPayments := httptest.NewRecorder()
	feeH.HandlePayments(rrPayments, reqPayments)
	if rrPayments.Code != http.StatusOK {
		t.Fatalf("expected 200 from HandlePayments, got %d", rrPayments.Code)
	}

	var payments []model.FeePayment
	_ = json.Unmarshal(rrPayments.Body.Bytes(), &payments)
	if len(payments) > 0 {
		reqReceipt := httptest.NewRequest(http.MethodGet, "/api/v1/fees/receipt?number="+payments[0].ReceiptNumber, nil)
		rrReceipt := httptest.NewRecorder()
		feeH.HandleReceipt(rrReceipt, reqReceipt)
		if rrReceipt.Code != http.StatusOK {
			t.Fatalf("expected 200 from HandleReceipt, got %d", rrReceipt.Code)
		}
	}

	// HandleReceipt missing number returns 400
	reqReceiptNoNum := httptest.NewRequest(http.MethodGet, "/api/v1/fees/receipt", nil)
	rrReceiptNoNum := httptest.NewRecorder()
	feeH.HandleReceipt(rrReceiptNoNum, reqReceiptNoNum)
	if rrReceiptNoNum.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from HandleReceipt without number, got %d", rrReceiptNoNum.Code)
	}

	// 9. HandleInvoicePDF
	reqPDF := httptest.NewRequest(http.MethodGet, "/api/v1/fees/invoices/pdf?id="+invoices[0].ID, nil)
	rrPDF := httptest.NewRecorder()
	feeH.HandleInvoicePDF(rrPDF, reqPDF)
	if rrPDF.Code != http.StatusOK {
		t.Fatalf("expected 200 from HandleInvoicePDF, got %d", rrPDF.Code)
	}
	if rrPDF.Header().Get("Content-Type") != "application/pdf" {
		t.Fatalf("expected application/pdf content type, got %s", rrPDF.Header().Get("Content-Type"))
	}
	if !strings.HasPrefix(rrPDF.Body.String(), "%PDF-1.4") {
		t.Fatalf("expected PDF-1.4 header")
	}

	// HandleInvoicePDF missing id
	reqPDFMissingID := httptest.NewRequest(http.MethodGet, "/api/v1/fees/invoices/pdf", nil)
	rrPDFMissingID := httptest.NewRecorder()
	feeH.HandleInvoicePDF(rrPDFMissingID, reqPDFMissingID)
	if rrPDFMissingID.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from HandleInvoicePDF without id, got %d", rrPDFMissingID.Code)
	}

	// HandleInvoicePDF not found
	reqPDFNotFound := httptest.NewRequest(http.MethodGet, "/api/v1/fees/invoices/pdf?id=missing-inv", nil)
	rrPDFNotFound := httptest.NewRecorder()
	feeH.HandleInvoicePDF(rrPDFNotFound, reqPDFNotFound)
	if rrPDFNotFound.Code != http.StatusNotFound {
		t.Fatalf("expected 404 from HandleInvoicePDF with invalid id, got %d", rrPDFNotFound.Code)
	}

	// HandleInvoicePDF wrong method
	reqPDFPost := httptest.NewRequest(http.MethodPost, "/api/v1/fees/invoices/pdf?id=some-id", nil)
	rrPDFPost := httptest.NewRecorder()
	feeH.HandleInvoicePDF(rrPDFPost, reqPDFPost)
	if rrPDFPost.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 from HandleInvoicePDF with POST, got %d", rrPDFPost.Code)
	}

	// 10. HandleReceiptPDF
	if len(payments) > 0 {
		reqReceiptPDF := httptest.NewRequest(http.MethodGet, "/api/v1/fees/receipts/pdf?number="+payments[0].ReceiptNumber, nil)
		rrReceiptPDF := httptest.NewRecorder()
		feeH.HandleReceiptPDF(rrReceiptPDF, reqReceiptPDF)
		if rrReceiptPDF.Code != http.StatusOK {
			t.Fatalf("expected 200 from HandleReceiptPDF, got %d", rrReceiptPDF.Code)
		}
		if rrReceiptPDF.Header().Get("Content-Type") != "application/pdf" {
			t.Fatalf("expected application/pdf content type, got %s", rrReceiptPDF.Header().Get("Content-Type"))
		}
		if !strings.HasPrefix(rrReceiptPDF.Body.String(), "%PDF-1.4") {
			t.Fatalf("expected PDF-1.4 header in receipt PDF")
		}
	}

	// HandleReceiptPDF missing number
	reqReceiptPDFNoNum := httptest.NewRequest(http.MethodGet, "/api/v1/fees/receipts/pdf", nil)
	rrReceiptPDFNoNum := httptest.NewRecorder()
	feeH.HandleReceiptPDF(rrReceiptPDFNoNum, reqReceiptPDFNoNum)
	if rrReceiptPDFNoNum.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from HandleReceiptPDF without number, got %d", rrReceiptPDFNoNum.Code)
	}

	// HandleReceiptPDF not found
	reqReceiptPDFNotFound := httptest.NewRequest(http.MethodGet, "/api/v1/fees/receipts/pdf?number=missing-rcp", nil)
	rrReceiptPDFNotFound := httptest.NewRecorder()
	feeH.HandleReceiptPDF(rrReceiptPDFNotFound, reqReceiptPDFNotFound)
	if rrReceiptPDFNotFound.Code != http.StatusNotFound {
		t.Fatalf("expected 404 from HandleReceiptPDF with invalid number, got %d", rrReceiptPDFNotFound.Code)
	}
}
