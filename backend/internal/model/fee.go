package model

import (
	"errors"
	"strings"
	"time"
)

// Fee types
const (
	FeeTypeTuition     = "tuition"
	FeeTypeHostel      = "hostel"
	FeeTypeMess        = "mess"
	FeeTypeTransport   = "transport"
	FeeTypeExamination = "examination"
	FeeTypeLaboratory  = "laboratory"
	FeeTypeAnnual      = "annual"
)

// Invoice statuses
const (
	InvoiceStatusPending = "pending"
	InvoiceStatusPartial = "partial"
	InvoiceStatusPaid    = "paid"
	InvoiceStatusOverdue = "overdue"
)

// Fine categories
const (
	FineCategoryLibrary         = "library"
	FineCategoryDisciplinary    = "disciplinary"
	FineCategoryHostelDamage    = "hostel_damage"
	FineCategoryLateRegistration = "late_registration"
	FineCategoryLaboratory      = "laboratory"
)

// Fine statuses
const (
	FineStatusUnpaid   = "unpaid"
	FineStatusPaid     = "paid"
	FineStatusWaived   = "waived"
	FineStatusAppealed = "appealed"
)

// Payment methods
const (
	PaymentMethodUPI        = "upi"
	PaymentMethodNetBanking = "net_banking"
	PaymentMethodDebitCard  = "debit_card"
	PaymentMethodCreditCard = "credit_card"
	PaymentMethodChallan    = "challan"
)

// FeeHead represents an itemized line item inside a fee invoice
type FeeHead struct {
	HeadName string  `json:"head_name"`
	Amount   float64 `json:"amount"`
}

// FeeInvoice represents an institutional semester or annual fee bill
type FeeInvoice struct {
	BaseSyncModel
	StudentID       string    `json:"student_id"`
	StudentName     string    `json:"student_name"`
	CampusHandle    string    `json:"campus_handle"`
	AcademicYear    string    `json:"academic_year"`
	SemesterNumber  int       `json:"semester_number"`
	FeeType         string    `json:"fee_type"`
	Title           string    `json:"title"`
	TotalAmount     float64   `json:"total_amount"`
	PaidAmount      float64   `json:"paid_amount"`
	DueAmount       float64   `json:"due_amount"`
	DueDate         time.Time `json:"due_date"`
	Status          string    `json:"status"` // pending, partial, paid, overdue
	Breakdown       []FeeHead `json:"breakdown,omitempty"`
}

// FineRecord represents a penalty or institutional fine imposed on a student
type FineRecord struct {
	BaseSyncModel
	StudentID    string     `json:"student_id"`
	StudentName  string     `json:"student_name"`
	CampusHandle string     `json:"campus_handle"`
	Category     string     `json:"category"` // library, disciplinary, hostel_damage, late_registration, laboratory
	Reason       string     `json:"reason"`
	Amount       float64    `json:"amount"`
	IssuedAt     time.Time  `json:"issued_at"`
	DueDate      time.Time  `json:"due_date"`
	Status       string     `json:"status"` // unpaid, paid, waived, appealed
	AppealReason string     `json:"appeal_reason,omitempty"`
	WaivedBy     string     `json:"waived_by,omitempty"`
	PaidAt       *time.Time `json:"paid_at,omitempty"`
	ReceiptID    string     `json:"receipt_id,omitempty"`
}

// FeePayment records an executed monetary settlement for an invoice or fine
type FeePayment struct {
	BaseSyncModel
	InvoiceID      string    `json:"invoice_id,omitempty"`
	FineID         string    `json:"fine_id,omitempty"`
	StudentID      string    `json:"student_id"`
	StudentName    string    `json:"student_name"`
	Amount         float64   `json:"amount"`
	PaymentMethod  string    `json:"payment_method"`
	TransactionRef string    `json:"transaction_ref"`
	PaymentStatus  string    `json:"payment_status"` // success, pending, failed
	PaidAt         time.Time `json:"paid_at"`
	ReceiptNumber  string    `json:"receipt_number"`
}

// FeeReceipt is the tamper-evident proof of settlement issued to a student
type FeeReceipt struct {
	ReceiptNumber  string    `json:"receipt_number"`
	PaymentID      string    `json:"payment_id"`
	InvoiceID      string    `json:"invoice_id,omitempty"`
	FineID         string    `json:"fine_id,omitempty"`
	StudentID      string    `json:"student_id"`
	StudentName    string    `json:"student_name"`
	CampusHandle   string    `json:"campus_handle"`
	Amount         float64   `json:"amount"`
	PaymentMethod  string    `json:"payment_method"`
	TransactionRef string    `json:"transaction_ref"`
	IssuedAt       time.Time `json:"issued_at"`
	Title          string    `json:"title"`
	Category       string    `json:"category"` // fee, fine
}

// FeeSummary aggregates dues and balances for student financial dashboard
type FeeSummary struct {
	TotalDues        float64    `json:"total_dues"`
	TotalPaid        float64    `json:"total_paid"`
	PendingFines     float64    `json:"pending_fines"`
	NextDueDate      *time.Time `json:"next_due_date,omitempty"`
	OverdueInvoices  int        `json:"overdue_invoices"`
	ActiveFinesCount int        `json:"active_fines_count"`
}

// PayInvoiceRequest encapsulates fee settlement input
type PayInvoiceRequest struct {
	InvoiceID     string  `json:"invoice_id"`
	StudentID     string  `json:"student_id"`
	Amount        float64 `json:"amount"`
	PaymentMethod string  `json:"payment_method"`
}

// PayFineRequest encapsulates fine settlement input
type PayFineRequest struct {
	FineID        string  `json:"fine_id"`
	StudentID     string  `json:"student_id"`
	PaymentMethod string  `json:"payment_method"`
}

// ValidateInvoice validates invoice structural integrity
func (inv *FeeInvoice) Validate() error {
	if strings.TrimSpace(inv.StudentID) == "" {
		return errors.New("student_id is required")
	}
	if strings.TrimSpace(inv.Title) == "" {
		return errors.New("invoice title is required")
	}
	if inv.TotalAmount <= 0 {
		return errors.New("total_amount must be greater than zero")
	}
	if inv.DueAmount < 0 {
		return errors.New("due_amount cannot be negative")
	}
	return nil
}

// ValidateFine validates fine penalty integrity
func (f *FineRecord) Validate() error {
	if strings.TrimSpace(f.StudentID) == "" {
		return errors.New("student_id is required")
	}
	if strings.TrimSpace(f.Reason) == "" {
		return errors.New("fine reason is required")
	}
	if f.Amount <= 0 {
		return errors.New("fine amount must be greater than zero")
	}
	return nil
}
