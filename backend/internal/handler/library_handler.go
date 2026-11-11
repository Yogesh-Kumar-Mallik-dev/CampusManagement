package handler

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

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

	case http.MethodDelete:
		id := r.URL.Query().Get("id")
		if id == "" {
			http.Error(w, `{"error":"id query parameter is required"}`, http.StatusBadRequest)
			return
		}
		if err := h.libService.DeletePhysicalBook(r.Context(), id); err != nil {
			http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]interface{}{"success": true, "message": "book removed from catalog", "id": id})

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

// HandleApproveBorrow handles POST /api/v1/library/borrow/approve
func (h *LibraryHandler) HandleApproveBorrow(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req model.ApproveBorrowRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
		return
	}

	borrow, err := h.libService.ApproveBorrow(r.Context(), req)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(borrow)
}

// HandleRejectBorrow handles POST /api/v1/library/borrow/reject
func (h *LibraryHandler) HandleRejectBorrow(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req model.RejectBorrowRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
		return
	}

	borrow, err := h.libService.RejectBorrow(r.Context(), req)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
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

// HandleApproveReturn handles POST /api/v1/library/return/approve
func (h *LibraryHandler) HandleApproveReturn(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req model.ApproveReturnRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
		return
	}

	borrow, err := h.libService.ApproveReturn(r.Context(), req)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(borrow)
}

// HandleRejectReturn handles POST /api/v1/library/return/reject
func (h *LibraryHandler) HandleRejectReturn(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req model.RejectReturnRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
		return
	}

	borrow, err := h.libService.RejectReturn(r.Context(), req)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(borrow)
}

// HandleApproveRenewal handles POST /api/v1/library/renew/approve
func (h *LibraryHandler) HandleApproveRenewal(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req model.ApproveRenewalRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
		return
	}

	borrow, err := h.libService.ApproveRenewal(r.Context(), req)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(borrow)
}

// HandleRejectRenewal handles POST /api/v1/library/renew/reject
func (h *LibraryHandler) HandleRejectRenewal(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req model.RejectRenewalRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
		return
	}

	borrow, err := h.libService.RejectRenewal(r.Context(), req)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(borrow)
}

// HandleEBooks handles GET /api/v1/library/ebooks, POST /api/v1/library/ebooks, and DELETE /api/v1/library/ebooks
func (h *LibraryHandler) HandleEBooks(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	switch r.Method {
	case http.MethodGet:
		if strings.Contains(r.URL.Path, "/download") {
			parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
			var ebookID string
			for i, p := range parts {
				if p == "ebooks" && i+1 < len(parts) {
					next := parts[i+1]
					if next == "download" && i+2 < len(parts) {
						ebookID = strings.TrimSuffix(parts[i+2], ".pdf")
					} else if next != "download" {
						ebookID = strings.TrimSuffix(next, ".pdf")
					}
					break
				}
			}
			if ebookID == "" {
				ebookID = r.URL.Query().Get("id")
			}
			ebooks, _ := h.libService.GetEBooks(r.Context(), "", "")
			var target *model.EBook
			for _, eb := range ebooks {
				if eb.ID == ebookID {
					target = &eb
					break
				}
			}
			if target == nil {
				target = &model.EBook{
					BaseSyncModel: model.BaseSyncModel{ID: ebookID},
					Title:         "Institutional E-Book",
					Author:        "Academic Faculty",
					Category:      "Computer Science",
					Format:        "PDF",
					FileSize:      "1.5 MB",
				}
			}
			pdfBytes, err := service.GenerateEBookPDF(target)
			if err != nil {
				http.Error(w, `{"error":"failed to generate PDF: `+err.Error()+`"}`, http.StatusInternalServerError)
				return
			}
			w.Header().Set("Content-Type", "application/pdf")
			w.Header().Set("Content-Disposition", fmt.Sprintf(`inline; filename="%s.pdf"`, target.ID))
			w.Header().Set("Content-Length", fmt.Sprintf("%d", len(pdfBytes)))
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write(pdfBytes)
			return
		}

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

	case http.MethodDelete:
		id := r.URL.Query().Get("id")
		if id == "" {
			http.Error(w, `{"error":"id query parameter is required"}`, http.StatusBadRequest)
			return
		}
		if err := h.libService.DeleteEBook(r.Context(), id); err != nil {
			http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]interface{}{"success": true, "message": "ebook removed", "id": id})

	default:
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
	}
}

// HandleApproveEBook handles POST /api/v1/library/ebooks/approve
func (h *LibraryHandler) HandleApproveEBook(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req model.ApproveEBookRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
		return
	}

	eb, err := h.libService.ApproveEBook(r.Context(), req)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(eb)
}

// HandleRejectEBook handles POST /api/v1/library/ebooks/reject
func (h *LibraryHandler) HandleRejectEBook(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req model.RejectEBookRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
		return
	}

	eb, err := h.libService.RejectEBook(r.Context(), req)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(eb)
}
