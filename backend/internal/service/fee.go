package service

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"

	"campus/backend/internal/model"

	"github.com/jackc/pgx/v5/pgxpool"
)

// FeeServiceInterface defines contracts for the institutional fee and fine subsystem
type FeeServiceInterface interface {
	GetFeeSummary(ctx context.Context, studentID string) (model.FeeSummary, error)
	GetInvoices(ctx context.Context, studentID string, status string) ([]model.FeeInvoice, error)
	GetInvoiceByID(ctx context.Context, id string) (*model.FeeInvoice, error)
	PayInvoice(ctx context.Context, req model.PayInvoiceRequest) (*model.FeePayment, *model.FeeReceipt, error)
	GetFines(ctx context.Context, studentID string, status string) ([]model.FineRecord, error)
	PayFine(ctx context.Context, req model.PayFineRequest) (*model.FeePayment, *model.FeeReceipt, error)
	AppealFine(ctx context.Context, fineID string, reason string) (*model.FineRecord, error)
	WaiveFine(ctx context.Context, fineID string, waivedBy string) (*model.FineRecord, error)
	GetPaymentRecords(ctx context.Context, studentID string) ([]model.FeePayment, error)
	GetReceipt(ctx context.Context, receiptNumber string) (*model.FeeReceipt, error)
	CreateInvoice(ctx context.Context, inv model.FeeInvoice) (*model.FeeInvoice, error)
	IssueFine(ctx context.Context, fine model.FineRecord) (*model.FineRecord, error)
	GenerateInvoicePDF(ctx context.Context, invoiceID string) ([]byte, string, error)
	GenerateReceiptPDF(ctx context.Context, receiptNumber string) ([]byte, string, error)
}

// FeeService implements FeeServiceInterface with memory-cached and database resilience
type FeeService struct {
	db          *pgxpool.Pool
	permService *PermissionService
	mu          sync.RWMutex

	invoices map[string]*model.FeeInvoice
	fines    map[string]*model.FineRecord
	payments map[string]*model.FeePayment
	receipts map[string]*model.FeeReceipt
}

// NewFeeService constructs and initializes FeeService with realistic seed data
func NewFeeService(db *pgxpool.Pool, permService *PermissionService) *FeeService {
	svc := &FeeService{
		db:          db,
		permService: permService,
		invoices:    make(map[string]*model.FeeInvoice),
		fines:       make(map[string]*model.FineRecord),
		payments:    make(map[string]*model.FeePayment),
		receipts:    make(map[string]*model.FeeReceipt),
	}
	svc.seedDefaults()
	return svc
}

func (s *FeeService) seedDefaults() {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now().UTC()
	studentID := "usr-harish_2025_l_btech_1"
	studentName := "Harish Kumar"
	handle := "harish_2025_l_btech_1"

	// 1. Tuition Invoice (Partial)
	inv1 := &model.FeeInvoice{
		BaseSyncModel: model.BaseSyncModel{
			ID:        "inv-tuition-2026-sem3",
			CreatedAt: now.Add(-30 * 24 * time.Hour),
			UpdatedAt: now.Add(-5 * 24 * time.Hour),
		},
		StudentID:      studentID,
		StudentName:    studentName,
		CampusHandle:   handle,
		AcademicYear:   "2026-2027",
		SemesterNumber: 3,
		FeeType:        model.FeeTypeTuition,
		Title:          "B.Tech Semester 3 Tuition & Curriculum Fee",
		TotalAmount:    65000,
		PaidAmount:     30000,
		DueAmount:      35000,
		DueDate:        now.Add(15 * 24 * time.Hour),
		Status:         model.InvoiceStatusPartial,
		Breakdown: []model.FeeHead{
			{HeadName: "Tuition & Instruction", Amount: 45000},
			{HeadName: "Computer & AI Lab Access", Amount: 12000},
			{HeadName: "Library & Digital Journals", Amount: 5000},
			{HeadName: "Examination & Assessment", Amount: 3000},
		},
	}
	s.invoices[inv1.ID] = inv1

	// 2. Hostel Accommodation Invoice (Pending)
	inv2 := &model.FeeInvoice{
		BaseSyncModel: model.BaseSyncModel{
			ID:        "inv-hostel-2026-sem3",
			CreatedAt: now.Add(-20 * 24 * time.Hour),
			UpdatedAt: now.Add(-20 * 24 * time.Hour),
		},
		StudentID:      studentID,
		StudentName:    studentName,
		CampusHandle:   handle,
		AcademicYear:   "2026-2027",
		SemesterNumber: 3,
		FeeType:        model.FeeTypeHostel,
		Title:          "Hostel Residency & Maintenance (BBDIT Hostel)",
		TotalAmount:    25000,
		PaidAmount:     0,
		DueAmount:      25000,
		DueDate:        now.Add(7 * 24 * time.Hour),
		Status:         model.InvoiceStatusPending,
		Breakdown: []model.FeeHead{
			{HeadName: "Room Rent (Double Occupancy)", Amount: 18000},
			{HeadName: "Electricity & High-Speed WiFi", Amount: 4500},
			{HeadName: "Maintenance & Sanitization", Amount: 2500},
		},
	}
	s.invoices[inv2.ID] = inv2

	// 3. Mess Dining Invoice (Paid)
	inv3 := &model.FeeInvoice{
		BaseSyncModel: model.BaseSyncModel{
			ID:        "inv-mess-2026-sem3",
			CreatedAt: now.Add(-45 * 24 * time.Hour),
			UpdatedAt: now.Add(-40 * 24 * time.Hour),
		},
		StudentID:      studentID,
		StudentName:    studentName,
		CampusHandle:   handle,
		AcademicYear:   "2026-2027",
		SemesterNumber: 3,
		FeeType:        model.FeeTypeMess,
		Title:          "Mess Boarding & Dining Operations (Semester 3)",
		TotalAmount:    18000,
		PaidAmount:     18000,
		DueAmount:      0,
		DueDate:        now.Add(-10 * 24 * time.Hour),
		Status:         model.InvoiceStatusPaid,
		Breakdown: []model.FeeHead{
			{HeadName: "Breakfast, Lunch & Dinner", Amount: 16000},
			{HeadName: "Special Sunday Dining & Festive Meals", Amount: 2000},
		},
	}
	s.invoices[inv3.ID] = inv3

	// Seed previous payments & receipts
	pay1 := &model.FeePayment{
		BaseSyncModel: model.BaseSyncModel{
			ID:        "pay-tuition-part-1",
			CreatedAt: now.Add(-5 * 24 * time.Hour),
			UpdatedAt: now.Add(-5 * 24 * time.Hour),
		},
		InvoiceID:      inv1.ID,
		StudentID:      studentID,
		StudentName:    studentName,
		Amount:         30000,
		PaymentMethod:  model.PaymentMethodUPI,
		TransactionRef: "UPI/2026/88492011",
		PaymentStatus:  "success",
		PaidAt:         now.Add(-5 * 24 * time.Hour),
		ReceiptNumber:  "RCP-2026-00412",
	}
	s.payments[pay1.ID] = pay1
	s.receipts[pay1.ReceiptNumber] = &model.FeeReceipt{
		ReceiptNumber:  pay1.ReceiptNumber,
		PaymentID:      pay1.ID,
		InvoiceID:      inv1.ID,
		StudentID:      studentID,
		StudentName:    studentName,
		CampusHandle:   handle,
		Amount:         pay1.Amount,
		PaymentMethod:  pay1.PaymentMethod,
		TransactionRef: pay1.TransactionRef,
		IssuedAt:       pay1.PaidAt,
		Title:          inv1.Title,
		Category:       "fee",
	}

	pay2 := &model.FeePayment{
		BaseSyncModel: model.BaseSyncModel{
			ID:        "pay-mess-full",
			CreatedAt: now.Add(-40 * 24 * time.Hour),
			UpdatedAt: now.Add(-40 * 24 * time.Hour),
		},
		InvoiceID:      inv3.ID,
		StudentID:      studentID,
		StudentName:    studentName,
		Amount:         18000,
		PaymentMethod:  model.PaymentMethodNetBanking,
		TransactionRef: "HDFC/NET/993182",
		PaymentStatus:  "success",
		PaidAt:         now.Add(-40 * 24 * time.Hour),
		ReceiptNumber:  "RCP-2026-00109",
	}
	s.payments[pay2.ID] = pay2
	s.receipts[pay2.ReceiptNumber] = &model.FeeReceipt{
		ReceiptNumber:  pay2.ReceiptNumber,
		PaymentID:      pay2.ID,
		InvoiceID:      inv3.ID,
		StudentID:      studentID,
		StudentName:    studentName,
		CampusHandle:   handle,
		Amount:         pay2.Amount,
		PaymentMethod:  pay2.PaymentMethod,
		TransactionRef: pay2.TransactionRef,
		IssuedAt:       pay2.PaidAt,
		Title:          inv3.Title,
		Category:       "fee",
	}

	// 4. Seed Fines
	fine1 := &model.FineRecord{
		BaseSyncModel: model.BaseSyncModel{
			ID:        "fine-lib-01",
			CreatedAt: now.Add(-10 * 24 * time.Hour),
			UpdatedAt: now.Add(-10 * 24 * time.Hour),
		},
		StudentID:    studentID,
		StudentName:  studentName,
		CampusHandle: handle,
		Category:     model.FineCategoryLibrary,
		Reason:       "Overdue book: 'Introduction to Algorithms' (Cormen et al.) overdue by 15 days",
		Amount:       150,
		IssuedAt:     now.Add(-10 * 24 * time.Hour),
		DueDate:      now.Add(5 * 24 * time.Hour),
		Status:       model.FineStatusUnpaid,
	}
	s.fines[fine1.ID] = fine1

	fine2 := &model.FineRecord{
		BaseSyncModel: model.BaseSyncModel{
			ID:        "fine-disc-01",
			CreatedAt: now.Add(-8 * 24 * time.Hour),
			UpdatedAt: now.Add(-2 * 24 * time.Hour),
		},
		StudentID:    studentID,
		StudentName:  studentName,
		CampusHandle: handle,
		Category:     model.FineCategoryDisciplinary,
		Reason:       "Hostel late entry past 10:30 PM without approved warden e-pass",
		Amount:       500,
		IssuedAt:     now.Add(-8 * 24 * time.Hour),
		DueDate:      now.Add(3 * 24 * time.Hour),
		Status:       model.FineStatusAppealed,
		AppealReason: "Was attending IEEE student branch robotics lab experiment with faculty supervisor permission",
	}
	s.fines[fine2.ID] = fine2
}

func (s *FeeService) GetFeeSummary(ctx context.Context, studentID string) (model.FeeSummary, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	summary := model.FeeSummary{}
	now := time.Now().UTC()
	var earliestDue *time.Time

	for _, inv := range s.invoices {
		if studentID != "" && inv.StudentID != studentID {
			continue
		}
		summary.TotalDues += inv.DueAmount
		summary.TotalPaid += inv.PaidAmount
		if inv.DueAmount > 0 {
			if inv.DueDate.Before(now) {
				summary.OverdueInvoices++
			}
			if earliestDue == nil || inv.DueDate.Before(*earliestDue) {
				dueDateCopy := inv.DueDate
				earliestDue = &dueDateCopy
			}
		}
	}

	for _, fine := range s.fines {
		if studentID != "" && fine.StudentID != studentID {
			continue
		}
		if fine.Status == model.FineStatusUnpaid || fine.Status == model.FineStatusAppealed {
			summary.PendingFines += fine.Amount
			summary.ActiveFinesCount++
		}
	}

	summary.NextDueDate = earliestDue
	return summary, nil
}

func (s *FeeService) GetInvoices(ctx context.Context, studentID string, status string) ([]model.FeeInvoice, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	cleanStatus := strings.ToLower(strings.TrimSpace(status))
	var result []model.FeeInvoice

	for _, inv := range s.invoices {
		if studentID != "" && inv.StudentID != studentID {
			continue
		}
		if cleanStatus != "" && strings.ToLower(inv.Status) != cleanStatus {
			continue
		}
		result = append(result, *inv)
	}

	sort.Slice(result, func(i, j int) bool {
		return result[i].DueDate.Before(result[j].DueDate)
	})

	return result, nil
}

func (s *FeeService) GetInvoiceByID(ctx context.Context, id string) (*model.FeeInvoice, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	inv, exists := s.invoices[id]
	if !exists {
		return nil, fmt.Errorf("fee invoice '%s' not found", id)
	}
	copy := *inv
	return &copy, nil
}

func (s *FeeService) PayInvoice(ctx context.Context, req model.PayInvoiceRequest) (*model.FeePayment, *model.FeeReceipt, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	inv, exists := s.invoices[req.InvoiceID]
	if !exists {
		return nil, nil, fmt.Errorf("fee invoice '%s' not found", req.InvoiceID)
	}

	if req.Amount <= 0 {
		return nil, nil, fmt.Errorf("payment amount must be greater than zero")
	}

	if req.Amount > inv.DueAmount {
		return nil, nil, fmt.Errorf("payment amount (%.2f) exceeds due balance (%.2f)", req.Amount, inv.DueAmount)
	}

	now := time.Now().UTC()
	inv.PaidAmount += req.Amount
	inv.DueAmount -= req.Amount
	inv.UpdatedAt = now

	if inv.DueAmount <= 0 {
		inv.Status = model.InvoiceStatusPaid
		inv.DueAmount = 0
	} else {
		inv.Status = model.InvoiceStatusPartial
	}

	method := strings.ToLower(strings.TrimSpace(req.PaymentMethod))
	if method == "" {
		method = model.PaymentMethodUPI
	}

	payID := fmt.Sprintf("pay-%d", time.Now().UnixNano())
	rcpNum := fmt.Sprintf("RCP-%d-%05d", now.Year(), len(s.payments)+1)
	txRef := fmt.Sprintf("TXN/%d/%04d", now.Unix(), len(s.payments)+1)

	payment := &model.FeePayment{
		BaseSyncModel: model.BaseSyncModel{
			ID:        payID,
			CreatedAt: now,
			UpdatedAt: now,
		},
		InvoiceID:      inv.ID,
		StudentID:      inv.StudentID,
		StudentName:    inv.StudentName,
		Amount:         req.Amount,
		PaymentMethod:  method,
		TransactionRef: txRef,
		PaymentStatus:  "success",
		PaidAt:         now,
		ReceiptNumber:  rcpNum,
	}
	s.payments[payment.ID] = payment

	receipt := &model.FeeReceipt{
		ReceiptNumber:  rcpNum,
		PaymentID:      payment.ID,
		InvoiceID:      inv.ID,
		StudentID:      inv.StudentID,
		StudentName:    inv.StudentName,
		CampusHandle:   inv.CampusHandle,
		Amount:         req.Amount,
		PaymentMethod:  method,
		TransactionRef: txRef,
		IssuedAt:       now,
		Title:          inv.Title,
		Category:       "fee",
	}
	s.receipts[receipt.ReceiptNumber] = receipt

	payCopy := *payment
	rcpCopy := *receipt
	return &payCopy, &rcpCopy, nil
}

func (s *FeeService) GetFines(ctx context.Context, studentID string, status string) ([]model.FineRecord, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	cleanStatus := strings.ToLower(strings.TrimSpace(status))
	var result []model.FineRecord

	for _, fine := range s.fines {
		if studentID != "" && fine.StudentID != studentID {
			continue
		}
		if cleanStatus != "" && strings.ToLower(fine.Status) != cleanStatus {
			continue
		}
		result = append(result, *fine)
	}

	sort.Slice(result, func(i, j int) bool {
		return result[i].IssuedAt.After(result[j].IssuedAt)
	})

	return result, nil
}

func (s *FeeService) PayFine(ctx context.Context, req model.PayFineRequest) (*model.FeePayment, *model.FeeReceipt, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	fine, exists := s.fines[req.FineID]
	if !exists {
		return nil, nil, fmt.Errorf("fine '%s' not found", req.FineID)
	}

	if fine.Status == model.FineStatusPaid {
		return nil, nil, fmt.Errorf("fine '%s' has already been paid", req.FineID)
	}
	if fine.Status == model.FineStatusWaived {
		return nil, nil, fmt.Errorf("fine '%s' was waived by administration and cannot be paid", req.FineID)
	}

	now := time.Now().UTC()
	fine.Status = model.FineStatusPaid
	fine.PaidAt = &now
	fine.UpdatedAt = now

	method := strings.ToLower(strings.TrimSpace(req.PaymentMethod))
	if method == "" {
		method = model.PaymentMethodUPI
	}

	payID := fmt.Sprintf("pay-fine-%d", time.Now().UnixNano())
	rcpNum := fmt.Sprintf("RCP-FINE-%d-%05d", now.Year(), len(s.payments)+1)
	txRef := fmt.Sprintf("TXN/FINE/%d/%04d", now.Unix(), len(s.payments)+1)

	payment := &model.FeePayment{
		BaseSyncModel: model.BaseSyncModel{
			ID:        payID,
			CreatedAt: now,
			UpdatedAt: now,
		},
		FineID:         fine.ID,
		StudentID:      fine.StudentID,
		StudentName:    fine.StudentName,
		Amount:         fine.Amount,
		PaymentMethod:  method,
		TransactionRef: txRef,
		PaymentStatus:  "success",
		PaidAt:         now,
		ReceiptNumber:  rcpNum,
	}
	s.payments[payment.ID] = payment

	receipt := &model.FeeReceipt{
		ReceiptNumber:  rcpNum,
		PaymentID:      payment.ID,
		FineID:         fine.ID,
		StudentID:      fine.StudentID,
		StudentName:    fine.StudentName,
		CampusHandle:   fine.CampusHandle,
		Amount:         fine.Amount,
		PaymentMethod:  method,
		TransactionRef: txRef,
		IssuedAt:       now,
		Title:          "Fine Clearance: " + fine.Reason,
		Category:       "fine",
	}
	s.receipts[receipt.ReceiptNumber] = receipt
	fine.ReceiptID = rcpNum

	payCopy := *payment
	rcpCopy := *receipt
	return &payCopy, &rcpCopy, nil
}

func (s *FeeService) AppealFine(ctx context.Context, fineID string, reason string) (*model.FineRecord, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	fine, exists := s.fines[fineID]
	if !exists {
		return nil, fmt.Errorf("fine '%s' not found", fineID)
	}

	if fine.Status == model.FineStatusPaid {
		return nil, fmt.Errorf("cannot appeal fine '%s': already settled", fineID)
	}
	if fine.Status == model.FineStatusWaived {
		return nil, fmt.Errorf("cannot appeal fine '%s': already waived", fineID)
	}

	cleanReason := strings.TrimSpace(reason)
	if cleanReason == "" {
		return nil, fmt.Errorf("appeal reason is required")
	}

	fine.Status = model.FineStatusAppealed
	fine.AppealReason = cleanReason
	fine.UpdatedAt = time.Now().UTC()

	copy := *fine
	return &copy, nil
}

func (s *FeeService) WaiveFine(ctx context.Context, fineID string, waivedBy string) (*model.FineRecord, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	fine, exists := s.fines[fineID]
	if !exists {
		return nil, fmt.Errorf("fine '%s' not found", fineID)
	}

	if fine.Status == model.FineStatusPaid {
		return nil, fmt.Errorf("cannot waive fine '%s': already settled", fineID)
	}

	cleanWaivedBy := strings.TrimSpace(waivedBy)
	if cleanWaivedBy == "" {
		cleanWaivedBy = "Administrator"
	}

	fine.Status = model.FineStatusWaived
	fine.WaivedBy = cleanWaivedBy
	fine.UpdatedAt = time.Now().UTC()

	copy := *fine
	return &copy, nil
}

func (s *FeeService) GetPaymentRecords(ctx context.Context, studentID string) ([]model.FeePayment, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []model.FeePayment
	for _, pay := range s.payments {
		if studentID != "" && pay.StudentID != studentID {
			continue
		}
		result = append(result, *pay)
	}

	sort.Slice(result, func(i, j int) bool {
		return result[i].PaidAt.After(result[j].PaidAt)
	})

	return result, nil
}

func (s *FeeService) GetReceipt(ctx context.Context, receiptNumber string) (*model.FeeReceipt, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	cleanNum := strings.TrimSpace(receiptNumber)
	rcp, exists := s.receipts[cleanNum]
	if !exists {
		return nil, fmt.Errorf("receipt '%s' not found", receiptNumber)
	}

	copy := *rcp
	return &copy, nil
}

func (s *FeeService) CreateInvoice(ctx context.Context, inv model.FeeInvoice) (*model.FeeInvoice, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if err := inv.Validate(); err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	if inv.ID == "" {
		inv.ID = fmt.Sprintf("inv-%d", now.UnixNano())
	}
	inv.CreatedAt = now
	inv.UpdatedAt = now
	if inv.DueAmount == 0 && inv.PaidAmount == 0 {
		inv.DueAmount = inv.TotalAmount
	}
	if inv.Status == "" {
		inv.Status = model.InvoiceStatusPending
	}

	s.invoices[inv.ID] = &inv
	copy := inv
	return &copy, nil
}

func (s *FeeService) IssueFine(ctx context.Context, fine model.FineRecord) (*model.FineRecord, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if err := fine.Validate(); err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	if fine.ID == "" {
		fine.ID = fmt.Sprintf("fine-%d", now.UnixNano())
	}
	fine.CreatedAt = now
	fine.UpdatedAt = now
	fine.IssuedAt = now
	if fine.DueDate.IsZero() {
		fine.DueDate = now.Add(14 * 24 * time.Hour)
	}
	fine.Status = model.FineStatusUnpaid

	s.fines[fine.ID] = &fine
	copy := fine
	return &copy, nil
}

func (s *FeeService) GenerateInvoicePDF(ctx context.Context, invoiceID string) ([]byte, string, error) {
	s.mu.RLock()
	inv, ok := s.invoices[invoiceID]
	s.mu.RUnlock()

	if !ok || inv == nil {
		return nil, "", fmt.Errorf("invoice '%s' not found", invoiceID)
	}

	pdfBytes, err := GenerateInvoicePDF(inv)
	if err != nil {
		return nil, "", err
	}

	filename := fmt.Sprintf("invoice-%s.pdf", inv.ID)
	return pdfBytes, filename, nil
}

func (s *FeeService) GenerateReceiptPDF(ctx context.Context, receiptNumber string) ([]byte, string, error) {
	s.mu.RLock()
	rcp, ok := s.receipts[receiptNumber]
	s.mu.RUnlock()

	if !ok || rcp == nil {
		return nil, "", fmt.Errorf("receipt '%s' not found", receiptNumber)
	}

	pdfBytes, err := GenerateReceiptPDF(rcp)
	if err != nil {
		return nil, "", err
	}

	filename := fmt.Sprintf("receipt-%s.pdf", rcp.ReceiptNumber)
	return pdfBytes, filename, nil
}
