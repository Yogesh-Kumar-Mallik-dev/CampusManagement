package service

import (
	"bytes"
	"testing"
	"time"

	"campus/backend/internal/model"
)

func TestPDFGenerators(t *testing.T) {
	if _, err := GenerateInvoicePDF(nil); err == nil {
		t.Fatal("expected error for nil invoice")
	}
	if _, err := GenerateReceiptPDF(nil); err == nil {
		t.Fatal("expected error for nil receipt")
	}
	if _, err := GenerateEBookPDF(nil); err == nil {
		t.Fatal("expected error for nil ebook")
	}

	inv := &model.FeeInvoice{
		BaseSyncModel:  model.BaseSyncModel{ID: "inv-1"},
		StudentID:      "usr-1",
		StudentName:    "Harish Kumar",
		CampusHandle:   "harish_2025_l_btech_1",
		Title:          "B.Tech Sem 3 Tuition",
		FeeType:        model.FeeTypeTuition,
		AcademicYear:   "2026-27",
		SemesterNumber: 3,
		TotalAmount:    55000,
		PaidAmount:     25000,
		DueAmount:      30000,
		DueDate:        time.Now().Add(7 * 24 * time.Hour),
		Status:         model.InvoiceStatusPartial,
		Breakdown: []model.FeeHead{
			{HeadName: "Tuition", Amount: 50000},
			{HeadName: "Library", Amount: 5000},
		},
	}
	invPDF, err := GenerateInvoicePDF(inv)
	if err != nil || !bytes.HasPrefix(invPDF, []byte("%PDF-1.4")) {
		t.Fatalf("GenerateInvoicePDF failed: len=%d err=%v", len(invPDF), err)
	}

	rcp := &model.FeeReceipt{
		ReceiptNumber:  "RCP-2026-001",
		PaymentID:      "pay-1",
		StudentID:      "usr-1",
		StudentName:    "Harish Kumar",
		CampusHandle:   "harish_2025_l_btech_1",
		Title:          "Tuition Fee",
		Category:       "fee",
		Amount:         25000,
		PaymentMethod:  model.PaymentMethodUPI,
		TransactionRef: "UPI/123456",
		IssuedAt:       time.Now().UTC(),
	}
	rcpPDF, err := GenerateReceiptPDF(rcp)
	if err != nil || !bytes.HasPrefix(rcpPDF, []byte("%PDF-1.4")) {
		t.Fatalf("GenerateReceiptPDF failed: len=%d err=%v", len(rcpPDF), err)
	}

	ebook := &model.EBook{
		BaseSyncModel:   model.BaseSyncModel{ID: "eb-1"},
		Title:           "Operating Systems Concepts",
		Author:          "Silberschatz",
		Category:        "Computer Science",
		Publisher:       "Wiley",
		Format:          "PDF",
		FileSize:        "2.4 MB",
		Description:     "Comprehensive textbook on operating systems kernels, concurrency, and storage.",
		SubmittedByName: "Prof. Sharma",
	}
	ebookPDF, err := GenerateEBookPDF(ebook)
	if err != nil || !bytes.HasPrefix(ebookPDF, []byte("%PDF-1.4")) {
		t.Fatalf("GenerateEBookPDF failed: len=%d err=%v", len(ebookPDF), err)
	}
}
