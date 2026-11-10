package model

import (
	"errors"
	"strings"
	"time"
)

// PhysicalBook represents a physical book asset cataloged in the institutional library
type PhysicalBook struct {
	BaseSyncModel
	ISBN            string  `json:"isbn"`
	Title           string  `json:"title"`
	Author          string  `json:"author"`
	Publisher       string  `json:"publisher"`
	Edition         string  `json:"edition"`
	Category        string  `json:"category"`
	DepartmentID    string  `json:"department_id"`
	TotalCopies     int     `json:"total_copies"`
	AvailableCopies int     `json:"available_copies"`
	ShelfLocation   string  `json:"shelf_location"`
	CoverURL        string  `json:"cover_url,omitempty"`
	ReplacementCost float64 `json:"replacement_cost"`
}

func (b *PhysicalBook) Validate() error {
	if strings.TrimSpace(b.Title) == "" {
		return errors.New("book title cannot be empty")
	}
	if strings.TrimSpace(b.Author) == "" {
		return errors.New("author cannot be empty")
	}
	if strings.TrimSpace(b.ISBN) == "" {
		return errors.New("isbn cannot be empty")
	}
	if b.TotalCopies < 1 {
		return errors.New("total copies must be at least 1")
	}
	if b.AvailableCopies < 0 || b.AvailableCopies > b.TotalCopies {
		return errors.New("available copies must be between 0 and total copies")
	}
	return nil
}

// BorrowStatus enumeration
const (
	BorrowStatusPendingApproval = "pending_approval"
	BorrowStatusPendingRenewal  = "pending_renewal"
	BorrowStatusPendingReturn   = "pending_return"
	BorrowStatusActive          = "active"
	BorrowStatusOverdue         = "overdue"
	BorrowStatusReturned        = "returned"
	BorrowStatusRejected        = "rejected"
)

// BorrowRecord represents an institutional loan transaction of a physical book
type BorrowRecord struct {
	BaseSyncModel
	BookID                 string     `json:"book_id"`
	BookTitle              string     `json:"book_title"`
	BookAuthor             string     `json:"book_author"`
	BookISBN               string     `json:"book_isbn"`
	ShelfLocation          string     `json:"shelf_location"`
	StudentID              string     `json:"student_id"`
	StudentName            string     `json:"student_name"`
	CampusHandle           string     `json:"campus_handle"`
	BorrowedAt             time.Time  `json:"borrowed_at"`
	DueDate                time.Time  `json:"due_date"`
	ReturnedAt             *time.Time `json:"returned_at,omitempty"`
	Status                 string     `json:"status"` // pending_approval, pending_renewal, pending_return, active, overdue, returned, rejected
	RenewalCount           int        `json:"renewal_count"`
	MaxRenewals            int        `json:"max_renewals"`
	FinePerDay             float64    `json:"fine_per_day"`
	AccruedLateFine        float64    `json:"accrued_late_fine"`
	LinkedFineRecordID     string     `json:"linked_fine_record_id,omitempty"`
	ApprovedBy             string     `json:"approved_by,omitempty"`
	ApprovedByName         string     `json:"approved_by_name,omitempty"`
	ApprovedAt             *time.Time `json:"approved_at,omitempty"`
	RejectionReason        string     `json:"rejection_reason,omitempty"`
	RenewalApprovedBy      string     `json:"renewal_approved_by,omitempty"`
	RenewalApprovedByName  string     `json:"renewal_approved_by_name,omitempty"`
	RenewalApprovedAt      *time.Time `json:"renewal_approved_at,omitempty"`
	RenewalRejectionReason string     `json:"renewal_rejection_reason,omitempty"`
	ReturnApprovedBy       string     `json:"return_approved_by,omitempty"`
	ReturnApprovedByName   string     `json:"return_approved_by_name,omitempty"`
	ReturnApprovedAt       *time.Time `json:"return_approved_at,omitempty"`
	ReturnRejectionReason  string     `json:"return_rejection_reason,omitempty"`
	Remarks                string     `json:"remarks,omitempty"`
}

func (r *BorrowRecord) Validate() error {
	if strings.TrimSpace(r.BookID) == "" {
		return errors.New("book id is required")
	}
	if strings.TrimSpace(r.StudentID) == "" {
		return errors.New("student id is required")
	}
	if r.DueDate.IsZero() {
		return errors.New("due date is required")
	}
	return nil
}

// EBookStatus enumeration
const (
	EBookStatusApproved = "approved"
	EBookStatusPending  = "pending_approval"
	EBookStatusRejected = "rejected"
)

// EBook represents a digital asset with infinite concurrent institutional borrowing
type EBook struct {
	BaseSyncModel
	Title             string     `json:"title"`
	Author            string     `json:"author"`
	Category          string     `json:"category"`
	Publisher         string     `json:"publisher"`
	Format            string     `json:"format"` // PDF, EPUB
	FileSize          string     `json:"file_size"`
	TotalReaders      int        `json:"total_readers"`
	DownloadURL       string     `json:"download_url"`
	ReadURL           string     `json:"read_url"`
	IsInfiniteBorrow  bool       `json:"is_infinite_borrow"`
	Description       string     `json:"description"`
	RequiredSemesters []int      `json:"required_semesters,omitempty"`
	Tags              []string   `json:"tags,omitempty"`
	Status            string     `json:"status"` // approved, pending_approval, rejected
	SubmittedBy       string     `json:"submitted_by,omitempty"`
	SubmittedByName   string     `json:"submitted_by_name,omitempty"`
	SubmittedByRole   string     `json:"submitted_by_role,omitempty"` // student, in_charge, librarian, admin
	ApprovedBy        string     `json:"approved_by,omitempty"`
	ApprovedByName    string     `json:"approved_by_name,omitempty"`
	ApprovedAt        *time.Time `json:"approved_at,omitempty"`
	RejectionReason   string     `json:"rejection_reason,omitempty"`
}

func (e *EBook) Validate() error {
	if strings.TrimSpace(e.Title) == "" {
		return errors.New("e-book title cannot be empty")
	}
	if strings.TrimSpace(e.Author) == "" {
		return errors.New("e-book author cannot be empty")
	}
	return nil
}

// LibrarySummary contains active metrics for a student's library profile
type LibrarySummary struct {
	StudentID            string    `json:"student_id"`
	MaxBorrowQuota       int       `json:"max_borrow_quota"`
	ActiveBorrowsCount   int       `json:"active_borrows_count"`
	RemainingQuota       int       `json:"remaining_quota"`
	OverdueCount         int       `json:"overdue_count"`
	TotalAccruedLateFine float64   `json:"total_accrued_late_fine"`
	EarliestDueDate      *time.Time `json:"earliest_due_date,omitempty"`
	TotalBooksRead       int       `json:"total_books_read"`
}

// BorrowBookRequest payload for borrowing a physical book
type BorrowBookRequest struct {
	BookID         string `json:"book_id"`
	StudentID      string `json:"student_id"`
	StudentName    string `json:"student_name"`
	CampusHandle   string `json:"campus_handle"`
	ApprovedBy     string `json:"approved_by,omitempty"`
	ApprovedByName string `json:"approved_by_name,omitempty"`
}

// ApproveBorrowRequest payload for Library In-Charge authorizing a loan
type ApproveBorrowRequest struct {
	BorrowID       string `json:"borrow_id"`
	ApprovedBy     string `json:"approved_by"`
	ApprovedByName string `json:"approved_by_name"`
	Remarks        string `json:"remarks,omitempty"`
}

// RejectBorrowRequest payload for Library In-Charge declining a loan
type RejectBorrowRequest struct {
	BorrowID        string `json:"borrow_id"`
	RejectedBy      string `json:"rejected_by"`
	RejectionReason string `json:"rejection_reason"`
}

// ReturnBookRequest payload for returning a physical book
type ReturnBookRequest struct {
	BorrowID       string `json:"borrow_id"`
	StudentID      string `json:"student_id"`
	ApprovedBy     string `json:"approved_by,omitempty"`
	ApprovedByName string `json:"approved_by_name,omitempty"`
}

// ApproveReturnRequest payload for Library In-Charge confirming physical copy return
type ApproveReturnRequest struct {
	BorrowID       string `json:"borrow_id"`
	ApprovedBy     string `json:"approved_by"`
	ApprovedByName string `json:"approved_by_name"`
	Remarks        string `json:"remarks,omitempty"`
}

// RejectReturnRequest payload for Library In-Charge rejecting return
type RejectReturnRequest struct {
	BorrowID        string `json:"borrow_id"`
	RejectedBy      string `json:"rejected_by"`
	RejectionReason string `json:"rejection_reason"`
}

// RenewBookRequest payload for extending a physical book loan
type RenewBookRequest struct {
	BorrowID       string `json:"borrow_id"`
	StudentID      string `json:"student_id"`
	ApprovedBy     string `json:"approved_by,omitempty"`
	ApprovedByName string `json:"approved_by_name,omitempty"`
}

// ApproveRenewalRequest payload for Library In-Charge authorizing loan renewal
type ApproveRenewalRequest struct {
	BorrowID       string `json:"borrow_id"`
	ApprovedBy     string `json:"approved_by"`
	ApprovedByName string `json:"approved_by_name"`
	Remarks        string `json:"remarks,omitempty"`
}

// RejectRenewalRequest payload for Library In-Charge declining loan renewal
type RejectRenewalRequest struct {
	BorrowID        string `json:"borrow_id"`
	RejectedBy      string `json:"rejected_by"`
	RejectionReason string `json:"rejection_reason"`
}

// ApproveEBookRequest payload for Library In-Charge authorizing a student-submitted PDF book
type ApproveEBookRequest struct {
	EBookID        string `json:"ebook_id"`
	ApprovedBy     string `json:"approved_by"`
	ApprovedByName string `json:"approved_by_name"`
	Remarks        string `json:"remarks,omitempty"`
}

// RejectEBookRequest payload for Library In-Charge declining a student-submitted PDF book
type RejectEBookRequest struct {
	EBookID         string `json:"ebook_id"`
	RejectedBy      string `json:"rejected_by"`
	RejectionReason string `json:"rejection_reason"`
}
