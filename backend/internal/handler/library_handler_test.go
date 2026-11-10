package handler

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

func TestLibraryHandlerEndpoints(t *testing.T) {
	feeSvc := service.NewFeeService(nil, nil)
	libSvc := service.NewLibraryService(nil, feeSvc)
	h := NewLibraryHandler(libSvc)

	const studentID = "usr-harish_2025_l_btech_1"

	// 1. HandleSummary
	reqSummary := httptest.NewRequest(http.MethodGet, "/api/v1/library/summary?student_id="+studentID, nil)
	rrSummary := httptest.NewRecorder()
	h.HandleSummary(rrSummary, reqSummary)
	if rrSummary.Code != http.StatusOK {
		t.Fatalf("expected 200 from HandleSummary, got %d", rrSummary.Code)
	}

	var summary model.LibrarySummary
	_ = json.Unmarshal(rrSummary.Body.Bytes(), &summary)
	if summary.MaxBorrowQuota != 4 {
		t.Fatalf("expected quota 4, got %d", summary.MaxBorrowQuota)
	}

	// Missing student_id
	reqNoStudent := httptest.NewRequest(http.MethodGet, "/api/v1/library/summary", nil)
	rrNoStudent := httptest.NewRecorder()
	h.HandleSummary(rrNoStudent, reqNoStudent)
	if rrNoStudent.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 from HandleSummary without student_id, got %d", rrNoStudent.Code)
	}

	// Method not allowed
	reqPostSummary := httptest.NewRequest(http.MethodPost, "/api/v1/library/summary", nil)
	rrPostSummary := httptest.NewRecorder()
	h.HandleSummary(rrPostSummary, reqPostSummary)
	if rrPostSummary.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405 on POST to summary, got %d", rrPostSummary.Code)
	}

	// 2. HandleBooks (GET catalog and by ID)
	reqBooks := httptest.NewRequest(http.MethodGet, "/api/v1/library/books", nil)
	rrBooks := httptest.NewRecorder()
	h.HandleBooks(rrBooks, reqBooks)
	if rrBooks.Code != http.StatusOK {
		t.Fatalf("expected 200 from HandleBooks, got %d", rrBooks.Code)
	}

	var books []model.PhysicalBook
	_ = json.Unmarshal(rrBooks.Body.Bytes(), &books)
	if len(books) == 0 {
		t.Fatal("expected books in catalog")
	}

	reqBookID := httptest.NewRequest(http.MethodGet, "/api/v1/library/books?id="+books[0].ID, nil)
	rrBookID := httptest.NewRecorder()
	h.HandleBooks(rrBookID, reqBookID)
	if rrBookID.Code != http.StatusOK {
		t.Fatalf("expected 200 from HandleBooks by ID, got %d", rrBookID.Code)
	}

	// 3. HandleBorrows
	reqBorrows := httptest.NewRequest(http.MethodGet, "/api/v1/library/borrows?student_id="+studentID, nil)
	rrBorrows := httptest.NewRecorder()
	h.HandleBorrows(rrBorrows, reqBorrows)
	if rrBorrows.Code != http.StatusOK {
		t.Fatalf("expected 200 from HandleBorrows, got %d", rrBorrows.Code)
	}

	var borrows []model.BorrowRecord
	_ = json.Unmarshal(rrBorrows.Body.Bytes(), &borrows)
	if len(borrows) == 0 {
		t.Fatal("expected borrow records")
	}

	// 4. HandleBorrowBook
	borrowBody, _ := json.Marshal(model.BorrowBookRequest{
		BookID:       "bk-net-01",
		StudentID:    "usr-fresh-student",
		StudentName:  "Fresh Student",
		CampusHandle: "fresh_student",
	})
	reqBorrow := httptest.NewRequest(http.MethodPost, "/api/v1/library/borrow", bytes.NewReader(borrowBody))
	rrBorrow := httptest.NewRecorder()
	h.HandleBorrowBook(rrBorrow, reqBorrow)
	if rrBorrow.Code != http.StatusCreated {
		t.Fatalf("expected 201 from HandleBorrowBook, got %d (%s)", rrBorrow.Code, rrBorrow.Body.String())
	}

	var newBorrow model.BorrowRecord
	_ = json.Unmarshal(rrBorrow.Body.Bytes(), &newBorrow)

	// 5. HandleApproveBorrow
	approveBody, _ := json.Marshal(model.ApproveBorrowRequest{
		BorrowID:       newBorrow.ID,
		ApprovedBy:     "usr-librarian-01",
		ApprovedByName: "Dr. Anita Sharma",
	})
	reqApprove := httptest.NewRequest(http.MethodPost, "/api/v1/library/borrow/approve", bytes.NewReader(approveBody))
	rrApprove := httptest.NewRecorder()
	h.HandleApproveBorrow(rrApprove, reqApprove)
	if rrApprove.Code != http.StatusOK {
		t.Fatalf("expected 200 from HandleApproveBorrow, got %d (%s)", rrApprove.Code, rrApprove.Body.String())
	}

	// Test HandleRejectBorrow on a separate request
	rejectBorrowReq, _ := json.Marshal(model.BorrowBookRequest{
		BookID:       "bk-db-01",
		StudentID:    "usr-rejected-student",
		StudentName:  "Test Reject",
		CampusHandle: "test_reject",
	})
	reqBorrowForReject := httptest.NewRequest(http.MethodPost, "/api/v1/library/borrow", bytes.NewReader(rejectBorrowReq))
	rrBorrowForReject := httptest.NewRecorder()
	h.HandleBorrowBook(rrBorrowForReject, reqBorrowForReject)
	var borrowToReject model.BorrowRecord
	_ = json.Unmarshal(rrBorrowForReject.Body.Bytes(), &borrowToReject)

	rejectBody, _ := json.Marshal(model.RejectBorrowRequest{
		BorrowID:        borrowToReject.ID,
		RejectedBy:      "usr-librarian-01",
		RejectionReason: "Reference copy only",
	})
	reqReject := httptest.NewRequest(http.MethodPost, "/api/v1/library/borrow/reject", bytes.NewReader(rejectBody))
	rrReject := httptest.NewRecorder()
	h.HandleRejectBorrow(rrReject, reqReject)
	if rrReject.Code != http.StatusOK {
		t.Fatalf("expected 200 from HandleRejectBorrow, got %d (%s)", rrReject.Code, rrReject.Body.String())
	}

	// 6. HandleRenewBook (student request -> pending_renewal)
	renewBody, _ := json.Marshal(model.RenewBookRequest{
		BorrowID:  newBorrow.ID,
		StudentID: "usr-fresh-student",
	})
	reqRenew := httptest.NewRequest(http.MethodPost, "/api/v1/library/renew", bytes.NewReader(renewBody))
	rrRenew := httptest.NewRecorder()
	h.HandleRenewBook(rrRenew, reqRenew)
	if rrRenew.Code != http.StatusOK {
		t.Fatalf("expected 200 from HandleRenewBook, got %d", rrRenew.Code)
	}

	// Approve Renewal
	appRenBody, _ := json.Marshal(model.ApproveRenewalRequest{
		BorrowID:       newBorrow.ID,
		ApprovedBy:     "usr-librarian-01",
		ApprovedByName: "Dr. Anita Sharma",
	})
	reqAppRen := httptest.NewRequest(http.MethodPost, "/api/v1/library/renew/approve", bytes.NewReader(appRenBody))
	rrAppRen := httptest.NewRecorder()
	h.HandleApproveRenewal(rrAppRen, reqAppRen)
	if rrAppRen.Code != http.StatusOK {
		t.Fatalf("expected 200 from HandleApproveRenewal, got %d (%s)", rrAppRen.Code, rrAppRen.Body.String())
	}

	// 7. HandleReturnBook (student request -> pending_return)
	returnBody, _ := json.Marshal(model.ReturnBookRequest{
		BorrowID:  newBorrow.ID,
		StudentID: "usr-fresh-student",
	})
	reqReturn := httptest.NewRequest(http.MethodPost, "/api/v1/library/return", bytes.NewReader(returnBody))
	rrReturn := httptest.NewRecorder()
	h.HandleReturnBook(rrReturn, reqReturn)
	if rrReturn.Code != http.StatusOK {
		t.Fatalf("expected 200 from HandleReturnBook, got %d", rrReturn.Code)
	}

	// Approve Return
	appRetBody, _ := json.Marshal(model.ApproveReturnRequest{
		BorrowID:       newBorrow.ID,
		ApprovedBy:     "usr-librarian-01",
		ApprovedByName: "Dr. Anita Sharma",
	})
	reqAppRet := httptest.NewRequest(http.MethodPost, "/api/v1/library/return/approve", bytes.NewReader(appRetBody))
	rrAppRet := httptest.NewRecorder()
	h.HandleApproveReturn(rrAppRet, reqAppRet)
	if rrAppRet.Code != http.StatusOK {
		t.Fatalf("expected 200 from HandleApproveReturn, got %d (%s)", rrAppRet.Code, rrAppRet.Body.String())
	}

	// 7. HandleEBooks
	reqEBooks := httptest.NewRequest(http.MethodGet, "/api/v1/library/ebooks", nil)
	rrEBooks := httptest.NewRecorder()
	h.HandleEBooks(rrEBooks, reqEBooks)
	if rrEBooks.Code != http.StatusOK {
		t.Fatalf("expected 200 from HandleEBooks, got %d", rrEBooks.Code)
	}

	var ebooks []model.EBook
	_ = json.Unmarshal(rrEBooks.Body.Bytes(), &ebooks)
	if len(ebooks) == 0 {
		t.Fatal("expected e-books in digital repository")
	}
}
