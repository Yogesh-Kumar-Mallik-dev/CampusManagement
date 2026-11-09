package handler

import (
	"encoding/json"
	"net/http"

	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

// LibraryHandler routes incoming HTTP traffic to LibraryServiceInterface
type LibraryHandler struct {
	libService service.LibraryServiceInterface
}

func NewLibraryHandler(libService service.LibraryServiceInterface) *LibraryHandler {
	return &LibraryHandler{libService: libService}
}

// HandleSummary handles GET /api/v1/library/summary?student_id={id}
func (h *LibraryHandler) HandleSummary(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	studentID := r.URL.Query().Get("student_id")
	if studentID == "" {
		http.Error(w, `{"error":"student_id query parameter is required"}`, http.StatusBadRequest)
		return
	}

	summary, err := h.libService.GetLibrarySummary(r.Context(), studentID)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(summary)
}

// HandleBooks handles GET /api/v1/library/books and POST /api/v1/library/books
func (h *LibraryHandler) HandleBooks(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	switch r.Method {
	case http.MethodGet:
		id := r.URL.Query().Get("id")
		if id != "" {
			book, err := h.libService.GetBookByID(r.Context(), id)
			if err != nil {
				http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusNotFound)
				return
			}
			_ = json.NewEncoder(w).Encode(book)
			return
		}

		q := r.URL.Query().Get("q")
		category := r.URL.Query().Get("category")
		books, err := h.libService.GetPhysicalBooks(r.Context(), q, category)
		if err != nil {
			http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
			return
		}
		_ = json.NewEncoder(w).Encode(books)

	case http.MethodPost:
		var book model.PhysicalBook
		if err := json.NewDecoder(r.Body).Decode(&book); err != nil {
			http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
			return
		}
		created, err := h.libService.CreatePhysicalBook(r.Context(), book)
		if err != nil {
			http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
			return
		}
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(created)

	default:
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
	}
}

// HandleBorrows handles GET /api/v1/library/borrows?student_id={id}&status={status}
func (h *LibraryHandler) HandleBorrows(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	studentID := r.URL.Query().Get("student_id")
	status := r.URL.Query().Get("status")
	borrows, err := h.libService.GetBorrowRecords(r.Context(), studentID, status)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(borrows)
}

// HandleBorrowBook handles POST /api/v1/library/borrow
func (h *LibraryHandler) HandleBorrowBook(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req model.BorrowBookRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
		return
	}

	borrow, err := h.libService.BorrowBook(r.Context(), req)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(borrow)
}

// HandleReturnBook handles POST /api/v1/library/return
func (h *LibraryHandler) HandleReturnBook(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req model.ReturnBookRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
		return
	}

	borrow, err := h.libService.ReturnBook(r.Context(), req)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(borrow)
}

// HandleRenewBook handles POST /api/v1/library/renew
func (h *LibraryHandler) HandleRenewBook(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req model.RenewBookRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
		return
	}

	borrow, err := h.libService.RenewBook(r.Context(), req)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(borrow)
}

// HandleEBooks handles GET /api/v1/library/ebooks and POST /api/v1/library/ebooks
func (h *LibraryHandler) HandleEBooks(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	switch r.Method {
	case http.MethodGet:
		q := r.URL.Query().Get("q")
		category := r.URL.Query().Get("category")
		ebooks, err := h.libService.GetEBooks(r.Context(), q, category)
		if err != nil {
			http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
			return
		}
		_ = json.NewEncoder(w).Encode(ebooks)

	case http.MethodPost:
		var ebook model.EBook
		if err := json.NewDecoder(r.Body).Decode(&ebook); err != nil {
			http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
			return
		}
		created, err := h.libService.CreateEBook(r.Context(), ebook)
		if err != nil {
			http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
			return
		}
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(created)

	default:
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
	}
}
