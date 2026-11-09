package service

import (
	"context"
	"testing"
	"time"

	"campus/backend/internal/model"
)

func TestFeeServiceOperations(t *testing.T) {
	svc := NewFeeService(nil, nil)
	ctx := context.Background()

	studentID := "usr-harish_2025_l_btech_1"

	// 1. GetFeeSummary
	summary, err := svc.GetFeeSummary(ctx, studentID)
	if err != nil {
		t.Fatalf("failed to get fee summary: %v", err)
	}
	if summary.TotalDues <= 0 {
		t.Fatalf("expected positive total dues, got %.2f", summary.TotalDues)
	}
	if summary.PendingFines <= 0 {
		t.Fatalf("expected positive pending fines, got %.2f", summary.PendingFines)
	}

	// Unfiltered summary
	allSummary, err := svc.GetFeeSummary(ctx, "")
	if err != nil || allSummary.TotalDues <= 0 {
		t.Fatalf("failed to get all fee summary: %v", err)
	}

	// 2. Invoices list & filter
	invoices, err := svc.GetInvoices(ctx, studentID, "")
	if err != nil || len(invoices) == 0 {
		t.Fatalf("expected invoices, got %v", err)
	}

	pendingInvoices, err := svc.GetInvoices(ctx, studentID, model.InvoiceStatusPending)
	if err != nil || len(pendingInvoices) == 0 {
		t.Fatalf("expected pending invoices, got %v", err)
	}

	// GetInvoiceByID
	invID := invoices[0].ID
	inv, err := svc.GetInvoiceByID(ctx, invID)
	if err != nil || inv.ID != invID {
		t.Fatalf("failed to get invoice by ID: %v", err)
	}

	_, err = svc.GetInvoiceByID(ctx, "non-existent-inv")
	if err == nil {
		t.Fatalf("expected error for non-existent invoice")
	}

	// 3. PayInvoice
	targetInv := pendingInvoices[0]
	payReq := model.PayInvoiceRequest{
		InvoiceID:     targetInv.ID,
		StudentID:     studentID,
		Amount:        targetInv.DueAmount,
		PaymentMethod: model.PaymentMethodUPI,
	}
	payRes, rcpRes, err := svc.PayInvoice(ctx, payReq)
	if err != nil {
		t.Fatalf("failed to pay invoice: %v", err)
	}
	if payRes.Amount != targetInv.DueAmount || rcpRes.ReceiptNumber == "" {
		t.Fatalf("unexpected payment or receipt: %v, %v", payRes, rcpRes)
	}

	// Pay invoice overpayment error
	_, _, err = svc.PayInvoice(ctx, model.PayInvoiceRequest{
		InvoiceID: targetInv.ID,
		StudentID: studentID,
		Amount:    5000,
	})
	if err == nil {
		t.Fatalf("expected error paying already settled invoice")
	}

	// Pay invoice zero or negative error
	_, _, err = svc.PayInvoice(ctx, model.PayInvoiceRequest{
		InvoiceID: targetInv.ID,
		StudentID: studentID,
		Amount:    0,
	})
	if err == nil {
		t.Fatalf("expected error for zero amount payment")
	}

	// Pay invoice missing invoice error
	_, _, err = svc.PayInvoice(ctx, model.PayInvoiceRequest{
		InvoiceID: "missing-inv",
		StudentID: studentID,
		Amount:    100,
	})
	if err == nil {
		t.Fatalf("expected error for missing invoice")
	}

	// Partial invoice payment
	partInv, err := svc.CreateInvoice(ctx, model.FeeInvoice{
		StudentID:    studentID,
		StudentName:  "Harish Kumar",
		CampusHandle: "harish_2025_l_btech_1",
		TotalAmount:  10000,
		Title:        "Annual Sports & Activity Fee",
		DueDate:      time.Now().Add(30 * 24 * time.Hour),
	})
	if err != nil {
		t.Fatalf("failed to create invoice: %v", err)
	}
	_, _, err = svc.PayInvoice(ctx, model.PayInvoiceRequest{
		InvoiceID: partInv.ID,
		StudentID: studentID,
		Amount:    4000,
	})
	if err != nil {
		t.Fatalf("failed to make partial payment: %v", err)
	}

	// 4. Fines, PayFine, AppealFine, WaiveFine
	fines, err := svc.GetFines(ctx, studentID, "")
	if err != nil || len(fines) == 0 {
		t.Fatalf("expected fines, got %v", err)
	}

	var unpaidFine model.FineRecord
	for _, f := range fines {
		if f.Status == model.FineStatusUnpaid {
			unpaidFine = f
			break
		}
	}

	// AppealFine
	appealed, err := svc.AppealFine(ctx, unpaidFine.ID, "Valid medical reason on the day of event")
	if err != nil || appealed.Status != model.FineStatusAppealed {
		t.Fatalf("failed to appeal fine: %v", err)
	}

	// AppealFine empty reason error
	_, err = svc.AppealFine(ctx, unpaidFine.ID, "")
	if err == nil {
		t.Fatalf("expected error for empty appeal reason")
	}

	// AppealFine missing fine error
	_, err = svc.AppealFine(ctx, "missing-fine", "Reason")
	if err == nil {
		t.Fatalf("expected error for missing fine appeal")
	}

	// WaiveFine
	waivedFine, err := svc.IssueFine(ctx, model.FineRecord{
		StudentID:    studentID,
		StudentName:  "Harish Kumar",
		CampusHandle: "harish_2025_l_btech_1",
		Category:     model.FineCategoryLibrary,
		Reason:       "Late book return due to campus lock",
		Amount:       50,
	})
	if err != nil {
		t.Fatalf("failed to issue fine: %v", err)
	}

	waived, err := svc.WaiveFine(ctx, waivedFine.ID, "Chief Librarian")
	if err != nil || waived.Status != model.FineStatusWaived || waived.WaivedBy != "Chief Librarian" {
		t.Fatalf("failed to waive fine: %v", err)
	}

	// Cannot appeal waived fine
	_, err = svc.AppealFine(ctx, waivedFine.ID, "Any reason")
	if err == nil {
		t.Fatalf("expected error appealing waived fine")
	}

	// Cannot pay waived fine
	_, _, err = svc.PayFine(ctx, model.PayFineRequest{
		FineID:    waivedFine.ID,
		StudentID: studentID,
	})
	if err == nil {
		t.Fatalf("expected error paying waived fine")
	}

	// PayFine valid
	payFineFine, err := svc.IssueFine(ctx, model.FineRecord{
		StudentID:    studentID,
		StudentName:  "Harish Kumar",
		CampusHandle: "harish_2025_l_btech_1",
		Category:     model.FineCategoryLaboratory,
		Reason:       "Glassware breakage in Chemistry Lab",
		Amount:       200,
	})
	if err != nil {
		t.Fatalf("failed to issue fine: %v", err)
	}

	payFineRes, rcpFineRes, err := svc.PayFine(ctx, model.PayFineRequest{
		FineID:        payFineFine.ID,
		StudentID:     studentID,
		PaymentMethod: model.PaymentMethodDebitCard,
	})
	if err != nil || payFineRes.Amount != 200 || rcpFineRes.Category != "fine" {
		t.Fatalf("failed to pay fine: %v", err)
	}

	// Cannot pay already paid fine
	_, _, err = svc.PayFine(ctx, model.PayFineRequest{
		FineID:    payFineFine.ID,
		StudentID: studentID,
	})
	if err == nil {
		t.Fatalf("expected error paying already paid fine")
	}

	// PayFine missing fine
	_, _, err = svc.PayFine(ctx, model.PayFineRequest{
		FineID:    "missing-fine",
		StudentID: studentID,
	})
	if err == nil {
		t.Fatalf("expected error paying missing fine")
	}

	// 5. Payment Records and Receipts
	payments, err := svc.GetPaymentRecords(ctx, studentID)
	if err != nil || len(payments) == 0 {
		t.Fatalf("failed to get payment records: %v", err)
	}

	rcp, err := svc.GetReceipt(ctx, rcpFineRes.ReceiptNumber)
	if err != nil || rcp.ReceiptNumber != rcpFineRes.ReceiptNumber {
		t.Fatalf("failed to get receipt: %v", err)
	}

	_, err = svc.GetReceipt(ctx, "non-existent-rcp")
	if err == nil {
		t.Fatalf("expected error for non-existent receipt")
	}

	// 6. Validation errors for CreateInvoice and IssueFine
	_, err = svc.CreateInvoice(ctx, model.FeeInvoice{
		StudentID: "",
	})
	if err == nil {
		t.Fatalf("expected validation error for invalid invoice")
	}

	_, err = svc.IssueFine(ctx, model.FineRecord{
		StudentID: "",
	})
	if err == nil {
		t.Fatalf("expected validation error for invalid fine")
	}
}
