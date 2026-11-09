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
	BorrowStatusActive   = "active"
	BorrowStatusOverdue  = "overdue"
	BorrowStatusReturned = "returned"
)

// BorrowRecord represents an institutional loan transaction of a physical book
type BorrowRecord struct {
	BaseSyncModel
	BookID             string     `json:"book_id"`
	BookTitle          string     `json:"book_title"`
	BookAuthor         string     `json:"book_author"`
	BookISBN           string     `json:"book_isbn"`
	ShelfLocation      string     `json:"shelf_location"`
	StudentID          string     `json:"student_id"`
	StudentName        string     `json:"student_name"`
	CampusHandle       string     `json:"campus_handle"`
	BorrowedAt         time.Time  `json:"borrowed_at"`
	DueDate            time.Time  `json:"due_date"`
	ReturnedAt         *time.Time `json:"returned_at,omitempty"`
	Status             string     `json:"status"` // active, overdue, returned
	RenewalCount       int        `json:"renewal_count"`
	MaxRenewals        int        `json:"max_renewals"`
	FinePerDay         float64    `json:"fine_per_day"`
	AccruedLateFine    float64    `json:"accrued_late_fine"`
	LinkedFineRecordID string     `json:"linked_fine_record_id,omitempty"`
	Remarks            string     `json:"remarks,omitempty"`
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

// EBook represents a digital asset with infinite concurrent institutional borrowing
type EBook struct {
	BaseSyncModel
	Title             string   `json:"title"`
	Author            string   `json:"author"`
	Category          string   `json:"category"`
	Publisher         string   `json:"publisher"`
	Format            string   `json:"format"` // PDF, EPUB
	FileSize          string   `json:"file_size"`
	TotalReaders      int      `json:"total_readers"`
	DownloadURL       string   `json:"download_url"`
	ReadURL           string   `json:"read_url"`
	IsInfiniteBorrow  bool     `json:"is_infinite_borrow"`
	Description       string   `json:"description"`
	RequiredSemesters []int    `json:"required_semesters,omitempty"`
	Tags              []string `json:"tags,omitempty"`
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
	BookID       string `json:"book_id"`
	StudentID    string `json:"student_id"`
	StudentName  string `json:"student_name"`
	CampusHandle string `json:"campus_handle"`
}

// ReturnBookRequest payload for returning a physical book
type ReturnBookRequest struct {
	BorrowID  string `json:"borrow_id"`
	StudentID string `json:"student_id"`
}

// RenewBookRequest payload for extending a physical book loan
type RenewBookRequest struct {
	BorrowID  string `json:"borrow_id"`
	StudentID string `json:"student_id"`
}
