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

	// 5. HandleRenewBook
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

	// 6. HandleReturnBook
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
