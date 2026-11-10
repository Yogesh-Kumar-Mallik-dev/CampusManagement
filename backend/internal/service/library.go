package service

import (
	"context"
	"errors"
	"fmt"
	"math"
	"sort"
	"strings"
	"sync"
	"time"

	"campus/backend/internal/model"

	"github.com/jackc/pgx/v5/pgxpool"
)

// LibraryServiceInterface defines contracts for the institutional library subsystem
type LibraryServiceInterface interface {
	GetLibrarySummary(ctx context.Context, studentID string) (model.LibrarySummary, error)
	GetPhysicalBooks(ctx context.Context, query string, category string) ([]model.PhysicalBook, error)
	GetBookByID(ctx context.Context, id string) (*model.PhysicalBook, error)
	GetBorrowRecords(ctx context.Context, studentID string, status string) ([]model.BorrowRecord, error)
	BorrowBook(ctx context.Context, req model.BorrowBookRequest) (*model.BorrowRecord, error)
	ApproveBorrow(ctx context.Context, req model.ApproveBorrowRequest) (*model.BorrowRecord, error)
	RejectBorrow(ctx context.Context, req model.RejectBorrowRequest) (*model.BorrowRecord, error)
	ReturnBook(ctx context.Context, req model.ReturnBookRequest) (*model.BorrowRecord, error)
	ApproveReturn(ctx context.Context, req model.ApproveReturnRequest) (*model.BorrowRecord, error)
	RejectReturn(ctx context.Context, req model.RejectReturnRequest) (*model.BorrowRecord, error)
	RenewBook(ctx context.Context, req model.RenewBookRequest) (*model.BorrowRecord, error)
	ApproveRenewal(ctx context.Context, req model.ApproveRenewalRequest) (*model.BorrowRecord, error)
	RejectRenewal(ctx context.Context, req model.RejectRenewalRequest) (*model.BorrowRecord, error)
	GetEBooks(ctx context.Context, query string, category string) ([]model.EBook, error)
	CreatePhysicalBook(ctx context.Context, book model.PhysicalBook) (*model.PhysicalBook, error)
	CreateEBook(ctx context.Context, ebook model.EBook) (*model.EBook, error)
}

// LibraryService implements LibraryServiceInterface with in-memory caching and Fine Portal synchronization
type LibraryService struct {
	db          *pgxpool.Pool
	feeService  FeeServiceInterface
	mu          sync.RWMutex

	books   map[string]*model.PhysicalBook
	borrows map[string]*model.BorrowRecord
	ebooks  map[string]*model.EBook
}

// NewLibraryService constructs and initializes LibraryService with institutional seed collections
func NewLibraryService(db *pgxpool.Pool, feeService FeeServiceInterface) *LibraryService {
	s := &LibraryService{
		db:         db,
		feeService: feeService,
		books:      make(map[string]*model.PhysicalBook),
		borrows:    make(map[string]*model.BorrowRecord),
		ebooks:     make(map[string]*model.EBook),
	}
	s.seedDefaultData()
	return s
}

func (s *LibraryService) seedDefaultData() {
	now := time.Now().UTC()

	// 1. Physical Catalog Books
	booksList := []*model.PhysicalBook{
		{
			BaseSyncModel:   model.BaseSyncModel{ID: "bk-algo-01", CreatedAt: now.Add(-60 * 24 * time.Hour), UpdatedAt: now},
			ISBN:            "978-0262033848",
			Title:           "Introduction to Algorithms (CLRS 3rd Edition)",
			Author:          "Thomas H. Cormen, Charles E. Leiserson",
			Publisher:       "MIT Press",
			Edition:         "3rd Edition",
			Category:        "Computer Science",
			DepartmentID:    "dept-cse",
			TotalCopies:     5,
			AvailableCopies: 3,
			ShelfLocation:   "Rack C-3, 2nd Floor Central Wing",
			ReplacementCost: 4500.0,
		},
		{
			BaseSyncModel:   model.BaseSyncModel{ID: "bk-os-01", CreatedAt: now.Add(-60 * 24 * time.Hour), UpdatedAt: now},
			ISBN:            "978-1118063330",
			Title:           "Operating System Concepts",
			Author:          "Abraham Silberschatz, Peter B. Galvin",
			Publisher:       "John Wiley & Sons",
			Edition:         "10th Edition",
			Category:        "Computer Science",
			DepartmentID:    "dept-cse",
			TotalCopies:     4,
			AvailableCopies: 1,
			ShelfLocation:   "Rack B-1, 2nd Floor West Wing",
			ReplacementCost: 3800.0,
		},
		{
			BaseSyncModel:   model.BaseSyncModel{ID: "bk-net-01", CreatedAt: now.Add(-60 * 24 * time.Hour), UpdatedAt: now},
			ISBN:            "978-0123850591",
			Title:           "Computer Networks: A Systems Approach",
			Author:          "Larry L. Peterson, Bruce S. Davie",
			Publisher:       "Morgan Kaufmann",
			Edition:         "5th Edition",
			Category:        "Computer Science",
			DepartmentID:    "dept-cse",
			TotalCopies:     3,
			AvailableCopies: 3,
			ShelfLocation:   "Rack D-2, 2nd Floor Central Wing",
			ReplacementCost: 3200.0,
		},
		{
			BaseSyncModel:   model.BaseSyncModel{ID: "bk-db-01", CreatedAt: now.Add(-60 * 24 * time.Hour), UpdatedAt: now},
			ISBN:            "978-0073523323",
			Title:           "Database System Concepts",
			Author:          "Abraham Silberschatz, Henry F. Korth",
			Publisher:       "McGraw-Hill",
			Edition:         "7th Edition",
			Category:        "Computer Science",
			DepartmentID:    "dept-cse",
			TotalCopies:     6,
			AvailableCopies: 4,
			ShelfLocation:   "Rack A-4, 2nd Floor East Wing",
			ReplacementCost: 4100.0,
		},
		{
			BaseSyncModel:   model.BaseSyncModel{ID: "bk-ai-01", CreatedAt: now.Add(-60 * 24 * time.Hour), UpdatedAt: now},
			ISBN:            "978-0136042594",
			Title:           "Artificial Intelligence: A Modern Approach",
			Author:          "Stuart Russell, Peter Norvig",
			Publisher:       "Pearson",
			Edition:         "4th Edition",
			Category:        "Artificial Intelligence",
			DepartmentID:    "dept-cse",
			TotalCopies:     4,
			AvailableCopies: 0,
			ShelfLocation:   "Rack C-1, 3rd Floor AI Wing",
			ReplacementCost: 5200.0,
		},
		{
			BaseSyncModel:   model.BaseSyncModel{ID: "bk-digital-01", CreatedAt: now.Add(-60 * 24 * time.Hour), UpdatedAt: now},
			ISBN:            "978-0132774208",
			Title:           "Digital Logic and Computer Design",
			Author:          "M. Morris Mano",
			Publisher:       "Prentice Hall",
			Edition:         "5th Edition",
			Category:        "Electronics",
			DepartmentID:    "dept-ece",
			TotalCopies:     5,
			AvailableCopies: 4,
			ShelfLocation:   "Rack E-2, 1st Floor ECE Section",
			ReplacementCost: 2900.0,
		},
	}

	for _, b := range booksList {
		s.books[b.ID] = b
	}

	// 2. Demo Student Borrows (Harish Kumar)
	const studentID = "usr-harish_2025_l_btech_1"
	const studentName = "Harish Kumar"
	const handle = "harish_2025_l_btech_1"

	// Loan 1: Active Loan (Due in 9 days)
	b1 := &model.BorrowRecord{
		BaseSyncModel:   model.BaseSyncModel{ID: "brw-clrs-01", CreatedAt: now.Add(-5 * 24 * time.Hour), UpdatedAt: now},
		BookID:          "bk-algo-01",
		BookTitle:       "Introduction to Algorithms (CLRS 3rd Edition)",
		BookAuthor:      "Thomas H. Cormen, Charles E. Leiserson",
		BookISBN:        "978-0262033848",
		ShelfLocation:   "Rack C-3, 2nd Floor Central Wing",
		StudentID:       studentID,
		StudentName:     studentName,
		CampusHandle:    handle,
		BorrowedAt:      now.Add(-5 * 24 * time.Hour),
		DueDate:         now.Add(9 * 24 * time.Hour),
		Status:          model.BorrowStatusActive,
		RenewalCount:    0,
		MaxRenewals:     2,
		FinePerDay:      10.0,
		AccruedLateFine: 0.0,
	}

	// Loan 2: Overdue Loan (Due 5 days ago, accrued 50 INR late fine, linked to fine portal!)
	b2 := &model.BorrowRecord{
		BaseSyncModel:      model.BaseSyncModel{ID: "brw-os-01", CreatedAt: now.Add(-19 * 24 * time.Hour), UpdatedAt: now},
		BookID:             "bk-os-01",
		BookTitle:          "Operating System Concepts",
		BookAuthor:         "Abraham Silberschatz, Peter B. Galvin",
		BookISBN:           "978-1118063330",
		ShelfLocation:      "Rack B-1, 2nd Floor West Wing",
		StudentID:          studentID,
		StudentName:        studentName,
		CampusHandle:       handle,
		BorrowedAt:         now.Add(-19 * 24 * time.Hour),
		DueDate:            now.Add(-5 * 24 * time.Hour),
		Status:             model.BorrowStatusOverdue,
		RenewalCount:       1,
		MaxRenewals:        2,
		FinePerDay:         10.0,
		AccruedLateFine:    50.0,
		LinkedFineRecordID: "fine-lib-01", // Linked to existing library fine in Fine Portal
		Remarks:            "Notice served; 5 days overdue penalty accrued",
	}

	// Loan 3: Returned Loan in history
	returnedTime := now.Add(-15 * 24 * time.Hour)
	b3 := &model.BorrowRecord{
		BaseSyncModel:   model.BaseSyncModel{ID: "brw-net-hist-01", CreatedAt: now.Add(-40 * 24 * time.Hour), UpdatedAt: returnedTime},
		BookID:          "bk-net-01",
		BookTitle:       "Computer Networks: A Systems Approach",
		BookAuthor:      "Larry L. Peterson, Bruce S. Davie",
		BookISBN:        "978-0123850591",
		ShelfLocation:   "Rack D-2, 2nd Floor Central Wing",
		StudentID:       studentID,
		StudentName:     studentName,
		CampusHandle:    handle,
		BorrowedAt:      now.Add(-40 * 24 * time.Hour),
		DueDate:         now.Add(-26 * 24 * time.Hour),
		ReturnedAt:      &returnedTime,
		Status:          model.BorrowStatusReturned,
		RenewalCount:    0,
		MaxRenewals:     2,
		FinePerDay:      10.0,
		AccruedLateFine: 0.0,
		Remarks:         "Returned in pristine condition without penalty",
	}

	s.borrows[b1.ID] = b1
	s.borrows[b2.ID] = b2
	s.borrows[b3.ID] = b3

	// 3. Digital E-Books for Infinite Borrowing
	ebooksList := []*model.EBook{
		{
			BaseSyncModel:    model.BaseSyncModel{ID: "ebk-ostep-01", CreatedAt: now.Add(-30 * 24 * time.Hour), UpdatedAt: now},
			Title:            "Operating Systems: Three Easy Pieces (OSTEP)",
			Author:           "Remzi H. Arpaci-Dusseau, Andrea C. Arpaci-Dusseau",
			Publisher:        "Arpaci-Dusseau Books",
			Category:         "Computer Science",
			Format:           "PDF",
			FileSize:         "18.4 MB",
			TotalReaders:     1420,
			DownloadURL:      "/api/v1/library/ebooks/ebk-ostep-01/download",
			ReadURL:          "/library/reader/ebk-ostep-01",
			IsInfiniteBorrow: true,
			Description:      "Comprehensive open textbook on virtualization, concurrency, and persistence used globally in modern operating systems courses.",
			Tags:             []string{"os", "systems", "concurrency", "storage"},
		},
		{
			BaseSyncModel:    model.BaseSyncModel{ID: "ebk-ddia-01", CreatedAt: now.Add(-30 * 24 * time.Hour), UpdatedAt: now},
			Title:            "Designing Data-Intensive Applications",
			Author:           "Martin Kleppmann",
			Publisher:        "O'Reilly Media",
			Category:         "Data Engineering",
			Format:           "EPUB",
			FileSize:         "12.8 MB",
			TotalReaders:     2180,
			DownloadURL:      "/api/v1/library/ebooks/ebk-ddia-01/download",
			ReadURL:          "/library/reader/ebk-ddia-01",
			IsInfiniteBorrow: true,
			Description:      "The definitive guide to distributed databases, replication, partitioning, streaming pipelines, and fault tolerance.",
			Tags:             []string{"distributed-systems", "databases", "kafka", "scalability"},
		},
		{
			BaseSyncModel:    model.BaseSyncModel{ID: "ebk-dl-01", CreatedAt: now.Add(-30 * 24 * time.Hour), UpdatedAt: now},
			Title:            "Deep Learning",
			Author:           "Ian Goodfellow, Yoshua Bengio, Aaron Courville",
			Publisher:        "MIT Press",
			Category:         "Artificial Intelligence",
			Format:           "PDF",
			FileSize:         "24.1 MB",
			TotalReaders:     3110,
			DownloadURL:      "/api/v1/library/ebooks/ebk-dl-01/download",
			ReadURL:          "/library/reader/ebk-dl-01",
			IsInfiniteBorrow: true,
			Description:      "Mathematical foundations, convolutional networks, sequence modeling, and generative architectures by pioneering AI researchers.",
			Tags:             []string{"deep-learning", "neural-networks", "math", "ai"},
		},
		{
			BaseSyncModel:    model.BaseSyncModel{ID: "ebk-discrete-01", CreatedAt: now.Add(-30 * 24 * time.Hour), UpdatedAt: now},
			Title:            "Discrete Mathematics and Its Applications",
			Author:           "Kenneth H. Rosen",
			Publisher:        "McGraw-Hill",
			Category:         "Mathematics",
			Format:           "PDF",
			FileSize:         "16.5 MB",
			TotalReaders:     980,
			DownloadURL:      "/api/v1/library/ebooks/ebk-discrete-01/download",
			ReadURL:          "/library/reader/ebk-discrete-01",
			IsInfiniteBorrow: true,
			Description:      "Combinatorics, graph theory, propositional logic, and algorithmic proofs foundational for engineering and computer science.",
			Tags:             []string{"math", "graphs", "combinatorics", "proofs"},
		},
		{
			BaseSyncModel:    model.BaseSyncModel{ID: "ebk-sicp-01", CreatedAt: now.Add(-30 * 24 * time.Hour), UpdatedAt: now},
			Title:            "Structure and Interpretation of Computer Programs (SICP)",
			Author:           "Harold Abelson, Gerald Jay Sussman",
			Publisher:        "MIT Press",
			Category:         "Computer Science",
			Format:           "EPUB",
			FileSize:         "8.6 MB",
			TotalReaders:     1650,
			DownloadURL:      "/api/v1/library/ebooks/ebk-sicp-01/download",
			ReadURL:          "/library/reader/ebk-sicp-01",
			IsInfiniteBorrow: true,
			Description:      "Classic computational philosophy emphasizing abstractions, meta-linguistic architecture, and functional programming.",
			Tags:             []string{"scheme", "functional", "lisp", "paradigms"},
		},
	}

	for _, eb := range ebooksList {
		s.ebooks[eb.ID] = eb
	}
}

func (s *LibraryService) GetLibrarySummary(ctx context.Context, studentID string) (model.LibrarySummary, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now().UTC()
	const maxQuota = 4

	activeCount := 0
	overdueCount := 0
	totalLateFine := 0.0
	var earliestDue *time.Time
	totalRead := 0

	for _, b := range s.borrows {
		if b.StudentID != studentID {
			continue
		}

		if b.Status == model.BorrowStatusReturned || b.Status == model.BorrowStatusRejected {
			if b.Status == model.BorrowStatusReturned {
				totalRead++
			}
			continue
		}

		// Active, Overdue, or Pending Approval
		activeCount++

		// Recalculate overdue status dynamically only for active loans past due date
		if b.Status != model.BorrowStatusPendingApproval && b.DueDate.Before(now) {
			b.Status = model.BorrowStatusOverdue
			overdueCount++
			daysOverdue := math.Ceil(now.Sub(b.DueDate).Hours() / 24.0)
			if daysOverdue > 0 {
				b.AccruedLateFine = daysOverdue * b.FinePerDay
				totalLateFine += b.AccruedLateFine
			}
		}

		if earliestDue == nil || b.DueDate.Before(*earliestDue) {
			t := b.DueDate
			earliestDue = &t
		}
	}

	remainingQuota := maxQuota - activeCount
	if remainingQuota < 0 {
		remainingQuota = 0
	}

	return model.LibrarySummary{
		StudentID:            studentID,
		MaxBorrowQuota:       maxQuota,
		ActiveBorrowsCount:   activeCount,
		RemainingQuota:       remainingQuota,
		OverdueCount:         overdueCount,
		TotalAccruedLateFine: totalLateFine,
		EarliestDueDate:      earliestDue,
		TotalBooksRead:       totalRead + activeCount,
	}, nil
}

func (s *LibraryService) GetPhysicalBooks(ctx context.Context, query string, category string) ([]model.PhysicalBook, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	q := strings.TrimSpace(strings.ToLower(query))
	cat := strings.TrimSpace(strings.ToLower(category))

	var list []model.PhysicalBook
	for _, b := range s.books {
		if cat != "" && cat != "all" && strings.ToLower(b.Category) != cat {
			continue
		}
		if q != "" {
			matchTitle := strings.Contains(strings.ToLower(b.Title), q)
			matchAuthor := strings.Contains(strings.ToLower(b.Author), q)
			matchISBN := strings.Contains(strings.ToLower(b.ISBN), q)
			if !matchTitle && !matchAuthor && !matchISBN {
				continue
			}
		}
		list = append(list, *b)
	}

	sort.Slice(list, func(i, j int) bool {
		return list[i].Title < list[j].Title
	})

	return list, nil
}

func (s *LibraryService) GetBookByID(ctx context.Context, id string) (*model.PhysicalBook, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	b, ok := s.books[id]
	if !ok || b == nil {
		return nil, fmt.Errorf("physical book '%s' not found", id)
	}
	copy := *b
	return &copy, nil
}

func (s *LibraryService) GetBorrowRecords(ctx context.Context, studentID string, status string) ([]model.BorrowRecord, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now().UTC()
	st := strings.TrimSpace(strings.ToLower(status))

	var list []model.BorrowRecord
	for _, b := range s.borrows {
		if studentID != "" && b.StudentID != studentID {
			continue
		}

		// Dynamically assess overdue fines if still unreturned and past deadline (active loans only)
		if b.Status != model.BorrowStatusReturned && b.Status != model.BorrowStatusRejected && b.Status != model.BorrowStatusPendingApproval && b.DueDate.Before(now) {
			b.Status = model.BorrowStatusOverdue
			days := math.Ceil(now.Sub(b.DueDate).Hours() / 24.0)
			if days > 0 {
				b.AccruedLateFine = days * b.FinePerDay
			}
		}

		if st != "" && st != "all" && strings.ToLower(b.Status) != st {
			continue
		}

		list = append(list, *b)
	}

	sort.Slice(list, func(i, j int) bool {
		return list[i].DueDate.Before(list[j].DueDate)
	})

	return list, nil
}

func (s *LibraryService) BorrowBook(ctx context.Context, req model.BorrowBookRequest) (*model.BorrowRecord, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if req.BookID == "" || req.StudentID == "" {
		return nil, errors.New("book_id and student_id are required to borrow")
	}

	book, ok := s.books[req.BookID]
	if !ok || book == nil {
		return nil, fmt.Errorf("book '%s' not found in catalog", req.BookID)
	}

	if book.AvailableCopies <= 0 {
		return nil, fmt.Errorf("all copies of '%s' are currently checked out", book.Title)
	}

	// Verify active borrow quota
	const maxQuota = 4
	activeCount := 0
	hasOverdue := false
	for _, b := range s.borrows {
		if b.StudentID == req.StudentID && b.Status != model.BorrowStatusReturned && b.Status != model.BorrowStatusRejected {
			activeCount++
			if (b.Status == model.BorrowStatusActive || b.Status == model.BorrowStatusOverdue) && b.DueDate.Before(time.Now().UTC()) {
				hasOverdue = true
			}
		}
	}

	if activeCount >= maxQuota {
		return nil, fmt.Errorf("borrowing quota exceeded (maximum %d active loans)", maxQuota)
	}

	if hasOverdue {
		return nil, errors.New("cannot borrow new books while overdue loans remain unreturned")
	}

	now := time.Now().UTC()
	dueDate := now.Add(14 * 24 * time.Hour) // 14-day institutional loan

	// Decrement available copies remaining
	book.AvailableCopies--
	book.UpdatedAt = now

	status := model.BorrowStatusPendingApproval
	var approvedAt *time.Time
	if req.ApprovedBy != "" {
		status = model.BorrowStatusActive
		approvedAt = &now
	}

	borrow := &model.BorrowRecord{
		BaseSyncModel: model.BaseSyncModel{
			ID:        fmt.Sprintf("brw-%d", now.UnixNano()),
			CreatedAt: now,
			UpdatedAt: now,
		},
		BookID:          book.ID,
		BookTitle:       book.Title,
		BookAuthor:      book.Author,
		BookISBN:        book.ISBN,
		ShelfLocation:   book.ShelfLocation,
		StudentID:       req.StudentID,
		StudentName:     req.StudentName,
		CampusHandle:    req.CampusHandle,
		BorrowedAt:      now,
		DueDate:         dueDate,
		Status:          status,
		RenewalCount:    0,
		MaxRenewals:     2,
		FinePerDay:      10.0,
		AccruedLateFine: 0.0,
		ApprovedBy:      req.ApprovedBy,
		ApprovedByName:  req.ApprovedByName,
		ApprovedAt:      approvedAt,
	}

	s.borrows[borrow.ID] = borrow
	copy := *borrow
	return &copy, nil
}

func (s *LibraryService) ApproveBorrow(ctx context.Context, req model.ApproveBorrowRequest) (*model.BorrowRecord, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if req.BorrowID == "" {
		return nil, errors.New("borrow_id is required")
	}
	if req.ApprovedBy == "" {
		return nil, errors.New("approved_by (library in-charge identity) is required")
	}

	borrow, ok := s.borrows[req.BorrowID]
	if !ok || borrow == nil {
		return nil, fmt.Errorf("borrow request '%s' not found", req.BorrowID)
	}

	if borrow.Status == model.BorrowStatusActive {
		return nil, errors.New("loan is already approved and active")
	}
	if borrow.Status == model.BorrowStatusReturned {
		return nil, errors.New("cannot approve an already returned loan")
	}

	now := time.Now().UTC()
	borrow.Status = model.BorrowStatusActive
	borrow.ApprovedBy = req.ApprovedBy
	borrow.ApprovedByName = req.ApprovedByName
	borrow.ApprovedAt = &now
	borrow.BorrowedAt = now
	borrow.DueDate = now.Add(14 * 24 * time.Hour) // 14-day loan starts upon in-charge approval
	if req.Remarks != "" {
		borrow.Remarks = req.Remarks
	}
	borrow.UpdatedAt = now

	copy := *borrow
	return &copy, nil
}

func (s *LibraryService) RejectBorrow(ctx context.Context, req model.RejectBorrowRequest) (*model.BorrowRecord, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if req.BorrowID == "" {
		return nil, errors.New("borrow_id is required")
	}
	if req.RejectedBy == "" {
		return nil, errors.New("rejected_by (library in-charge identity) is required")
	}

	borrow, ok := s.borrows[req.BorrowID]
	if !ok || borrow == nil {
		return nil, fmt.Errorf("borrow request '%s' not found", req.BorrowID)
	}

	if borrow.Status == model.BorrowStatusActive {
		return nil, errors.New("cannot reject an already active loan; return the book instead")
	}
	if borrow.Status == model.BorrowStatusReturned {
		return nil, errors.New("cannot reject an already returned loan")
	}

	now := time.Now().UTC()
	borrow.Status = model.BorrowStatusRejected
	reason := req.RejectionReason
	if strings.TrimSpace(reason) == "" {
		reason = "Declined by Library In-Charge"
	}
	borrow.RejectionReason = reason
	borrow.UpdatedAt = now

	// Restore physical copy back to catalog
	if book, exists := s.books[borrow.BookID]; exists && book != nil {
		if book.AvailableCopies < book.TotalCopies {
			book.AvailableCopies++
			book.UpdatedAt = now
		}
	}

	copy := *borrow
	return &copy, nil
}

func (s *LibraryService) ReturnBook(ctx context.Context, req model.ReturnBookRequest) (*model.BorrowRecord, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	borrow, ok := s.borrows[req.BorrowID]
	if !ok || borrow == nil {
		return nil, fmt.Errorf("borrow record '%s' not found", req.BorrowID)
	}

	if borrow.Status == model.BorrowStatusReturned {
		return nil, errors.New("book has already been returned")
	}

	now := time.Now().UTC()

	// If approvedBy is provided (e.g. direct in-charge operation), complete return immediately
	if req.ApprovedBy != "" {
		return s.completeReturnLocked(ctx, borrow, req.ApprovedBy, req.ApprovedByName, now)
	}

	// Otherwise, transition to pending_return awaiting Library In-Charge verification
	borrow.Status = model.BorrowStatusPendingReturn
	borrow.UpdatedAt = now

	copy := *borrow
	return &copy, nil
}

func (s *LibraryService) completeReturnLocked(ctx context.Context, borrow *model.BorrowRecord, approvedBy, approvedByName string, now time.Time) (*model.BorrowRecord, error) {
	borrow.ReturnedAt = &now
	borrow.Status = model.BorrowStatusReturned
	borrow.ReturnApprovedBy = approvedBy
	borrow.ReturnApprovedByName = approvedByName
	borrow.ReturnApprovedAt = &now
	borrow.UpdatedAt = now

	// Increment available copies remaining
	if book, exists := s.books[borrow.BookID]; exists && book != nil {
		if book.AvailableCopies < book.TotalCopies {
			book.AvailableCopies++
			book.UpdatedAt = now
		}
	}

	// Calculate and issue late fine if returned after due date
	if now.After(borrow.DueDate) {
		daysLate := math.Ceil(now.Sub(borrow.DueDate).Hours() / 24.0)
		if daysLate > 0 {
			borrow.AccruedLateFine = daysLate * borrow.FinePerDay

			// Automatically link to institutional Fine Portal if FeeService is available
			if s.feeService != nil && borrow.LinkedFineRecordID == "" {
				fineReason := fmt.Sprintf("Late return of library book '%s' (ISBN: %s) by %d days",
					borrow.BookTitle, borrow.BookISBN, int(daysLate))
				fineRec, err := s.feeService.IssueFine(ctx, model.FineRecord{
					StudentID:    borrow.StudentID,
					StudentName:  borrow.StudentName,
					CampusHandle: borrow.CampusHandle,
					Category:     model.FineCategoryLibrary,
					Reason:       fineReason,
					Amount:       borrow.AccruedLateFine,
				})
				if err == nil && fineRec != nil {
					borrow.LinkedFineRecordID = fineRec.ID
				}
			}
		}
	}

	copy := *borrow
	return &copy, nil
}

func (s *LibraryService) ApproveReturn(ctx context.Context, req model.ApproveReturnRequest) (*model.BorrowRecord, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if req.BorrowID == "" {
		return nil, errors.New("borrow_id is required")
	}
	if req.ApprovedBy == "" {
		return nil, errors.New("approved_by (library in-charge identity) is required")
	}

	borrow, ok := s.borrows[req.BorrowID]
	if !ok || borrow == nil {
		return nil, fmt.Errorf("borrow record '%s' not found", req.BorrowID)
	}

	if borrow.Status == model.BorrowStatusReturned {
		return nil, errors.New("book has already been returned and checked in")
	}

	now := time.Now().UTC()
	return s.completeReturnLocked(ctx, borrow, req.ApprovedBy, req.ApprovedByName, now)
}

func (s *LibraryService) RejectReturn(ctx context.Context, req model.RejectReturnRequest) (*model.BorrowRecord, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if req.BorrowID == "" {
		return nil, errors.New("borrow_id is required")
	}
	if req.RejectedBy == "" {
		return nil, errors.New("rejected_by (library in-charge identity) is required")
	}

	borrow, ok := s.borrows[req.BorrowID]
	if !ok || borrow == nil {
		return nil, fmt.Errorf("borrow record '%s' not found", req.BorrowID)
	}

	if borrow.Status != model.BorrowStatusPendingReturn {
		return nil, errors.New("can only reject returns that are currently pending in-charge verification")
	}

	now := time.Now().UTC()
	if now.After(borrow.DueDate) {
		borrow.Status = model.BorrowStatusOverdue
	} else {
		borrow.Status = model.BorrowStatusActive
	}

	reason := req.RejectionReason
	if strings.TrimSpace(reason) == "" {
		reason = "Return rejected by Library In-Charge (condition check failed)"
	}
	borrow.ReturnRejectionReason = reason
	borrow.UpdatedAt = now

	copy := *borrow
	return &copy, nil
}

func (s *LibraryService) RenewBook(ctx context.Context, req model.RenewBookRequest) (*model.BorrowRecord, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	borrow, ok := s.borrows[req.BorrowID]
	if !ok || borrow == nil {
		return nil, fmt.Errorf("borrow record '%s' not found", req.BorrowID)
	}

	if borrow.Status == model.BorrowStatusReturned {
		return nil, errors.New("cannot renew a returned book")
	}

	if borrow.RenewalCount >= borrow.MaxRenewals {
		return nil, fmt.Errorf("maximum renewal limit (%d) reached for this loan", borrow.MaxRenewals)
	}

	now := time.Now().UTC()
	if now.After(borrow.DueDate.Add(24 * time.Hour)) {
		return nil, errors.New("overdue loans cannot be renewed; please return to clear penalties")
	}

	// If approvedBy is provided (e.g. direct in-charge operation), complete renewal immediately
	if req.ApprovedBy != "" {
		borrow.RenewalCount++
		borrow.DueDate = borrow.DueDate.Add(14 * 24 * time.Hour) // Extend by 14 days
		borrow.Status = model.BorrowStatusActive
		borrow.RenewalApprovedBy = req.ApprovedBy
		borrow.RenewalApprovedByName = req.ApprovedByName
		borrow.RenewalApprovedAt = &now
		borrow.UpdatedAt = now

		copy := *borrow
		return &copy, nil
	}

	// Otherwise, transition to pending_renewal awaiting Library In-Charge approval
	borrow.Status = model.BorrowStatusPendingRenewal
	borrow.UpdatedAt = now

	copy := *borrow
	return &copy, nil
}

func (s *LibraryService) ApproveRenewal(ctx context.Context, req model.ApproveRenewalRequest) (*model.BorrowRecord, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if req.BorrowID == "" {
		return nil, errors.New("borrow_id is required")
	}
	if req.ApprovedBy == "" {
		return nil, errors.New("approved_by (library in-charge identity) is required")
	}

	borrow, ok := s.borrows[req.BorrowID]
	if !ok || borrow == nil {
		return nil, fmt.Errorf("borrow record '%s' not found", req.BorrowID)
	}

	if borrow.RenewalCount >= borrow.MaxRenewals {
		return nil, fmt.Errorf("maximum renewal limit (%d) reached for this loan", borrow.MaxRenewals)
	}

	now := time.Now().UTC()
	borrow.RenewalCount++
	borrow.DueDate = borrow.DueDate.Add(14 * 24 * time.Hour)
	borrow.Status = model.BorrowStatusActive
	borrow.RenewalApprovedBy = req.ApprovedBy
	borrow.RenewalApprovedByName = req.ApprovedByName
	borrow.RenewalApprovedAt = &now
	borrow.UpdatedAt = now

	copy := *borrow
	return &copy, nil
}

func (s *LibraryService) RejectRenewal(ctx context.Context, req model.RejectRenewalRequest) (*model.BorrowRecord, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if req.BorrowID == "" {
		return nil, errors.New("borrow_id is required")
	}
	if req.RejectedBy == "" {
		return nil, errors.New("rejected_by (library in-charge identity) is required")
	}

	borrow, ok := s.borrows[req.BorrowID]
	if !ok || borrow == nil {
		return nil, fmt.Errorf("borrow record '%s' not found", req.BorrowID)
	}

	if borrow.Status != model.BorrowStatusPendingRenewal {
		return nil, errors.New("can only reject renewals that are currently pending in-charge authorization")
	}

	now := time.Now().UTC()
	if now.After(borrow.DueDate) {
		borrow.Status = model.BorrowStatusOverdue
	} else {
		borrow.Status = model.BorrowStatusActive
	}

	reason := req.RejectionReason
	if strings.TrimSpace(reason) == "" {
		reason = "Renewal declined by Library In-Charge"
	}
	borrow.RenewalRejectionReason = reason
	borrow.UpdatedAt = now

	copy := *borrow
	return &copy, nil
}

func (s *LibraryService) GetEBooks(ctx context.Context, query string, category string) ([]model.EBook, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	q := strings.TrimSpace(strings.ToLower(query))
	cat := strings.TrimSpace(strings.ToLower(category))

	var list []model.EBook
	for _, eb := range s.ebooks {
		if cat != "" && cat != "all" && strings.ToLower(eb.Category) != cat {
			continue
		}
		if q != "" {
			matchTitle := strings.Contains(strings.ToLower(eb.Title), q)
			matchAuthor := strings.Contains(strings.ToLower(eb.Author), q)
			matchDesc := strings.Contains(strings.ToLower(eb.Description), q)
			if !matchTitle && !matchAuthor && !matchDesc {
				continue
			}
		}
		list = append(list, *eb)
	}

	sort.Slice(list, func(i, j int) bool {
		return list[i].TotalReaders > list[j].TotalReaders
	})

	return list, nil
}

func (s *LibraryService) CreatePhysicalBook(ctx context.Context, book model.PhysicalBook) (*model.PhysicalBook, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if err := book.Validate(); err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	if book.ID == "" {
		book.ID = fmt.Sprintf("bk-%d", now.UnixNano())
	}
	book.CreatedAt = now
	book.UpdatedAt = now
	if book.AvailableCopies == 0 && book.TotalCopies > 0 {
		book.AvailableCopies = book.TotalCopies
	}

	s.books[book.ID] = &book
	copy := book
	return &copy, nil
}

func (s *LibraryService) CreateEBook(ctx context.Context, ebook model.EBook) (*model.EBook, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if err := ebook.Validate(); err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	if ebook.ID == "" {
		ebook.ID = fmt.Sprintf("ebk-%d", now.UnixNano())
	}
	ebook.CreatedAt = now
	ebook.UpdatedAt = now
	ebook.IsInfiniteBorrow = true

	s.ebooks[ebook.ID] = &ebook
	copy := ebook
	return &copy, nil
}
