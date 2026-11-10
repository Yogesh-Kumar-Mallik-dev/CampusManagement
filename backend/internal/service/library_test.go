package service

import (
	"context"
	"testing"

	"campus/backend/internal/model"
)

func TestLibraryServiceOperations(t *testing.T) {
	feeSvc := NewFeeService(nil, nil)
	libSvc := NewLibraryService(nil, feeSvc)
	ctx := context.Background()

	const studentID = "usr-harish_2025_l_btech_1"

	// 1. Library Summary
	summary, err := libSvc.GetLibrarySummary(ctx, studentID)
	if err != nil {
		t.Fatalf("failed to get library summary: %v", err)
	}
	if summary.MaxBorrowQuota != 4 {
		t.Fatalf("expected max quota 4, got %d", summary.MaxBorrowQuota)
	}
	if summary.ActiveBorrowsCount == 0 {
		t.Fatalf("expected active borrows for student")
	}
	if summary.OverdueCount == 0 {
		t.Fatalf("expected at least 1 overdue borrow in seed data")
	}
	if summary.TotalAccruedLateFine <= 0 {
		t.Fatalf("expected accrued late fine > 0, got %f", summary.TotalAccruedLateFine)
	}

	// 2. Physical Books Catalog & Search
	books, err := libSvc.GetPhysicalBooks(ctx, "", "all")
	if err != nil || len(books) == 0 {
		t.Fatalf("expected physical books catalog, got %v", err)
	}

	filteredBooks, err := libSvc.GetPhysicalBooks(ctx, "Algorithms", "Computer Science")
	if err != nil || len(filteredBooks) != 1 {
		t.Fatalf("expected 1 algorithm book, got %d", len(filteredBooks))
	}

	book, err := libSvc.GetBookByID(ctx, "bk-algo-01")
	if err != nil || book.Title != "Introduction to Algorithms (CLRS 3rd Edition)" {
		t.Fatalf("failed to get book by id: %v", err)
	}

	_, err = libSvc.GetBookByID(ctx, "non-existent-book")
	if err == nil {
		t.Fatalf("expected error on non-existent book")
	}

	// 3. Borrow Records & Fines
	borrows, err := libSvc.GetBorrowRecords(ctx, studentID, "all")
	if err != nil || len(borrows) == 0 {
		t.Fatalf("expected borrow records for student")
	}

	activeBorrows, err := libSvc.GetBorrowRecords(ctx, studentID, model.BorrowStatusActive)
	if err != nil || len(activeBorrows) == 0 {
		t.Fatalf("expected active borrow records")
	}

	// 4. Borrow New Book
	// Pick book with available copies
	availBook := "bk-net-01" // 3 copies available
	initialAvail := 0
	for _, b := range books {
		if b.ID == availBook {
			initialAvail = b.AvailableCopies
		}
	}

	// Harish already has an overdue book so cannot borrow immediately unless overdue is cleared
	_, err = libSvc.BorrowBook(ctx, model.BorrowBookRequest{
		BookID:       availBook,
		StudentID:    studentID,
		StudentName:  "Harish Kumar",
		CampusHandle: "harish_2025_l_btech_1",
	})
	if err == nil {
		t.Fatalf("expected error borrowing while having an overdue loan")
	}

	// Another student with clean record requests to borrow
	const newStudent = "usr-clean-student"
	borrowedRecord, err := libSvc.BorrowBook(ctx, model.BorrowBookRequest{
		BookID:       availBook,
		StudentID:    newStudent,
		StudentName:  "Pooja Sharma",
		CampusHandle: "pooja_sharma",
	})
	if err != nil || borrowedRecord == nil {
		t.Fatalf("failed to borrow book: %v", err)
	}
	if borrowedRecord.Status != model.BorrowStatusPendingApproval {
		t.Fatalf("expected pending_approval status, got %s", borrowedRecord.Status)
	}

	// Verify available copies remaining was decremented
	updatedBook, _ := libSvc.GetBookByID(ctx, availBook)
	if updatedBook.AvailableCopies != initialAvail-1 {
		t.Fatalf("expected available copies to be %d, got %d", initialAvail-1, updatedBook.AvailableCopies)
	}

	// Library In-Charge reviews and approves the loan
	approvedRecord, err := libSvc.ApproveBorrow(ctx, model.ApproveBorrowRequest{
		BorrowID:       borrowedRecord.ID,
		ApprovedBy:     "usr-librarian-01",
		ApprovedByName: "Dr. Anita Sharma (Library In-Charge)",
		Remarks:        "Verified student identity card and approved loan",
	})
	if err != nil || approvedRecord.Status != model.BorrowStatusActive {
		t.Fatalf("failed to approve borrow request: %v", err)
	}
	if approvedRecord.ApprovedBy != "usr-librarian-01" || approvedRecord.ApprovedByName == "" {
		t.Fatalf("expected approved_by metadata to be set")
	}

	// Test rejection flow for a different request
	availBook2 := "bk-db-01"
	book2Before, _ := libSvc.GetBookByID(ctx, availBook2)
	req2, err := libSvc.BorrowBook(ctx, model.BorrowBookRequest{
		BookID:       availBook2,
		StudentID:    "usr-rejected-student",
		StudentName:  "Vikram Rao",
		CampusHandle: "vikram_rao",
	})
	if err != nil {
		t.Fatalf("failed to create second borrow request: %v", err)
	}
	rejectedRecord, err := libSvc.RejectBorrow(ctx, model.RejectBorrowRequest{
		BorrowID:        req2.ID,
		RejectedBy:      "usr-librarian-01",
		RejectionReason: "Course reference copy reserved for in-library reading",
	})
	if err != nil || rejectedRecord.Status != model.BorrowStatusRejected {
		t.Fatalf("failed to reject borrow request: %v", err)
	}
	book2After, _ := libSvc.GetBookByID(ctx, availBook2)
	if book2After.AvailableCopies != book2Before.AvailableCopies {
		t.Fatalf("expected copies restored on rejection")
	}

	// 5. Renew Book (Student requests renewal -> pending_renewal -> In-Charge approves)
	renewReq, err := libSvc.RenewBook(ctx, model.RenewBookRequest{
		BorrowID:  borrowedRecord.ID,
		StudentID: newStudent,
	})
	if err != nil || renewReq.Status != model.BorrowStatusPendingRenewal {
		t.Fatalf("expected pending_renewal status, got %v", renewReq)
	}

	renewed, err := libSvc.ApproveRenewal(ctx, model.ApproveRenewalRequest{
		BorrowID:       borrowedRecord.ID,
		ApprovedBy:     "usr-librarian-01",
		ApprovedByName: "Dr. Anita Sharma (Library In-Charge)",
	})
	if err != nil || renewed.RenewalCount != 1 || renewed.Status != model.BorrowStatusActive {
		t.Fatalf("failed to approve renewal: %v", err)
	}

	// Test renewal rejection on a separate active borrow
	activeForRenewal, _ := libSvc.BorrowBook(ctx, model.BorrowBookRequest{
		BookID:         availBook,
		StudentID:      "usr-renew-reject",
		ApprovedBy:     "usr-librarian-01",
		ApprovedByName: "Dr. Anita Sharma",
	})
	renReq2, _ := libSvc.RenewBook(ctx, model.RenewBookRequest{
		BorrowID:  activeForRenewal.ID,
		StudentID: "usr-renew-reject",
	})
	if renReq2.Status != model.BorrowStatusPendingRenewal {
		t.Fatalf("expected pending_renewal, got %s", renReq2.Status)
	}
	rejectedRen, err := libSvc.RejectRenewal(ctx, model.RejectRenewalRequest{
		BorrowID:        activeForRenewal.ID,
		RejectedBy:      "usr-librarian-01",
		RejectionReason: "High demand hold queue prevents extension",
	})
	if err != nil || rejectedRen.Status != model.BorrowStatusActive || rejectedRen.RenewalCount != 0 {
		t.Fatalf("failed to reject renewal: %v", err)
	}

	// 6. Return Book (Student requests return -> pending_return -> In-Charge inspects & approves)
	retReq, err := libSvc.ReturnBook(ctx, model.ReturnBookRequest{
		BorrowID:  borrowedRecord.ID,
		StudentID: newStudent,
	})
	if err != nil || retReq.Status != model.BorrowStatusPendingReturn {
		t.Fatalf("expected pending_return status, got %v", retReq)
	}

	returned, err := libSvc.ApproveReturn(ctx, model.ApproveReturnRequest{
		BorrowID:       borrowedRecord.ID,
		ApprovedBy:     "usr-librarian-01",
		ApprovedByName: "Dr. Anita Sharma (Library In-Charge)",
	})
	if err != nil || returned.Status != model.BorrowStatusReturned {
		t.Fatalf("failed to return book: %v", err)
	}

	// Test return rejection on a separate pending return
	retReq2, _ := libSvc.ReturnBook(ctx, model.ReturnBookRequest{
		BorrowID:  activeForRenewal.ID,
		StudentID: "usr-renew-reject",
	})
	if retReq2.Status != model.BorrowStatusPendingReturn {
		t.Fatalf("expected pending_return, got %s", retReq2.Status)
	}
	rejectedRet, err := libSvc.RejectReturn(ctx, model.RejectReturnRequest{
		BorrowID:        activeForRenewal.ID,
		RejectedBy:      "usr-librarian-01",
		RejectionReason: "Binding damaged - inspect before check-in",
	})
	if err != nil || rejectedRet.Status != model.BorrowStatusActive {
		t.Fatalf("failed to reject return: %v", err)
	}
	// Return activeForRenewal cleanly with in-charge direct signature
	_, _ = libSvc.ReturnBook(ctx, model.ReturnBookRequest{
		BorrowID:       activeForRenewal.ID,
		StudentID:      "usr-renew-reject",
		ApprovedBy:     "usr-librarian-01",
		ApprovedByName: "Dr. Anita Sharma",
	})

	// Verify available copies incremented back
	afterReturnBook, _ := libSvc.GetBookByID(ctx, availBook)
	if afterReturnBook.AvailableCopies != initialAvail {
		t.Fatalf("expected available copies restored to %d, got %d", initialAvail, afterReturnBook.AvailableCopies)
	}

	// 7. Late Return triggers Fine Portal integration
	// Return the overdue book 'brw-os-01' with in-charge direct sign-off
	lateReturned, err := libSvc.ReturnBook(ctx, model.ReturnBookRequest{
		BorrowID:       "brw-os-01",
		StudentID:      studentID,
		ApprovedBy:     "usr-librarian-01",
		ApprovedByName: "Dr. Anita Sharma",
	})
	if err != nil {
		t.Fatalf("failed to return overdue book: %v", err)
	}
	if lateReturned.AccruedLateFine <= 0 {
		t.Fatalf("expected accrued late fine on overdue return")
	}

	// 8. E-Books for Infinite Borrowing
	ebooks, err := libSvc.GetEBooks(ctx, "", "all")
	if err != nil || len(ebooks) == 0 {
		t.Fatalf("expected infinite e-books catalog")
	}
	for _, eb := range ebooks {
		if !eb.IsInfiniteBorrow {
			t.Fatalf("expected all e-books to have IsInfiniteBorrow=true")
		}
	}

	filteredEBooks, err := libSvc.GetEBooks(ctx, "Distributed", "Data Engineering")
	if err != nil || len(filteredEBooks) == 0 {
		t.Fatalf("expected DDIA ebook in data engineering search")
	}

	// 9. Book and EBook creation & validation
	newBk, err := libSvc.CreatePhysicalBook(ctx, model.PhysicalBook{
		Title:           "Clean Code",
		Author:          "Robert C. Martin",
		ISBN:            "978-0132350884",
		TotalCopies:     3,
		AvailableCopies: 3,
		ShelfLocation:   "Rack A-1",
	})
	if err != nil || newBk.ID == "" {
		t.Fatalf("failed to create physical book: %v", err)
	}

	newEb, err := libSvc.CreateEBook(ctx, model.EBook{
		Title:       "You Don't Know JS",
		Author:      "Kyle Simpson",
		Category:    "Web Development",
		Format:      "PDF",
		DownloadURL: "/api/v1/library/ebooks/ydkjs/download",
	})
	if err != nil || newEb.ID == "" {
		t.Fatalf("failed to create ebook: %v", err)
	}

	// 10. Delete Physical Book (Remove Catalogue)
	// Try deleting a book with active/pending loans (e.g., 'bk-algo-01' has active loan b1)
	err = libSvc.DeletePhysicalBook(ctx, "bk-algo-01")
	if err == nil {
		t.Fatalf("expected error deleting catalogue book with active/pending loans")
	}

	// Delete the newly created book with zero loans
	err = libSvc.DeletePhysicalBook(ctx, newBk.ID)
	if err != nil {
		t.Fatalf("failed to remove catalogue book without active loans: %v", err)
	}
	_, err = libSvc.GetBookByID(ctx, newBk.ID)
	if err == nil {
		t.Fatalf("expected book to be removed from catalog")
	}

	// 11. Student PDF Book Submission & In-Charge Approval
	studentPdf, err := libSvc.CreateEBook(ctx, model.EBook{
		Title:           "Introduction to Compiler Design",
		Author:          "Torben Mogensen",
		Category:        "Computer Science",
		Format:          "PDF",
		FileSize:        "9.4 MB",
		SubmittedBy:     studentID,
		SubmittedByName: "Harish Kumar",
		SubmittedByRole: "student",
	})
	if err != nil {
		t.Fatalf("failed to submit student PDF book: %v", err)
	}
	if studentPdf.Status != model.EBookStatusPending {
		t.Fatalf("expected student submitted PDF book to be pending_approval, got %s", studentPdf.Status)
	}

	// Approve PDF Book
	approvedPdf, err := libSvc.ApproveEBook(ctx, model.ApproveEBookRequest{
		EBookID:        studentPdf.ID,
		ApprovedBy:     "usr-librarian-01",
		ApprovedByName: "Dr. Anita Sharma",
		Remarks:        "Verified PDF contents and syllabus relevance",
	})
	if err != nil || approvedPdf.Status != model.EBookStatusApproved {
		t.Fatalf("failed to approve student PDF book: %v", err)
	}

	// Reject another student submission
	rejectedSubmission, err := libSvc.CreateEBook(ctx, model.EBook{
		Title:           "Draft Notes 2024",
		Author:          "Unknown",
		Category:        "Computer Science",
		Format:          "PDF",
		SubmittedBy:     studentID,
		SubmittedByName: "Harish Kumar",
		SubmittedByRole: "student",
	})
	if err != nil {
		t.Fatalf("failed to create student draft: %v", err)
	}
	rejectedPdf, err := libSvc.RejectEBook(ctx, model.RejectEBookRequest{
		EBookID:         rejectedSubmission.ID,
		RejectedBy:      "usr-librarian-01",
		RejectionReason: "Incomplete notes document; missing required textbook chapters",
	})
	if err != nil || rejectedPdf.Status != model.EBookStatusRejected {
		t.Fatalf("failed to reject student PDF book: %v", err)
	}
}
