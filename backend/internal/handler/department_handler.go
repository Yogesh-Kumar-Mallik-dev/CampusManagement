package handler

import (
	"encoding/json"
	"net/http"
	"strings"

	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

type DepartmentHandler struct {
	academicService *service.AcademicService
	userResolver    func(id string) (model.User, bool)
	teacherProvider func() []model.User
}

func NewDepartmentHandler(
	academicService *service.AcademicService,
	userResolver func(id string) (model.User, bool),
	teacherProvider func() []model.User,
) *DepartmentHandler {
	return &DepartmentHandler{
		academicService: academicService,
		userResolver:    userResolver,
		teacherProvider: teacherProvider,
	}
}

// HandleDepartments handles GET /api/v1/departments and POST /api/v1/departments
func (h *DepartmentHandler) HandleDepartments(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		// Check if requesting specific department by ID query or suffix
		id := r.URL.Query().Get("id")
		if id != "" {
			h.getDepartmentDetail(w, r, id)
			return
		}

		departments, err := h.academicService.ListDepartments(r.Context())
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(departments)

	case http.MethodPost:
		var req model.CreateDepartmentRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
			return
		}

		if strings.TrimSpace(req.Code) == "" || strings.TrimSpace(req.Name) == "" {
			http.Error(w, "Department code and name are required", http.StatusBadRequest)
			return
		}

		// Resolve HOD name if provided
		if req.HODID != nil && *req.HODID != "" && h.userResolver != nil {
			if hod, found := h.userResolver(*req.HODID); found {
				name := hod.FullName()
				req.HODID = &hod.ID
				_ = name
			}
		}

		created, err := h.academicService.CreateDepartment(r.Context(), req)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		if created.HODID != nil && *created.HODID != "" && h.userResolver != nil {
			if hod, found := h.userResolver(*created.HODID); found {
				created.HODName = hod.FullName()
			}
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(created)

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func (h *DepartmentHandler) getDepartmentDetail(w http.ResponseWriter, r *http.Request, deptID string) {
	detail, err := h.academicService.GetDepartmentDetail(r.Context(), deptID, h.userResolver)
	if err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}

	if detail.Department.HODID != nil && *detail.Department.HODID != "" && h.userResolver != nil {
		if hod, found := h.userResolver(*detail.Department.HODID); found {
			detail.Department.HODName = hod.FullName()
		}
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(detail)
}

// HandlePrograms handles GET /api/v1/academics/programs
func (h *DepartmentHandler) HandlePrograms(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	programs, err := h.academicService.ListPrograms(r.Context())
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(programs)
}

// HandleSubjects handles GET /api/v1/academics/subjects
func (h *DepartmentHandler) HandleSubjects(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	subjects, err := h.academicService.ListSubjects(r.Context())
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(subjects)
}

// HandleSemesters handles GET /api/v1/academics/semesters
func (h *DepartmentHandler) HandleSemesters(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	id := r.URL.Query().Get("id")
	if id != "" {
		detail, err := h.academicService.GetSemesterDetail(r.Context(), id, h.userResolver)
		if err != nil {
			http.Error(w, err.Error(), http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(detail)
		return
	}

	semesters, err := h.academicService.ListSemesters(r.Context())
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(semesters)
}

// HandleTeachers handles GET /api/v1/academics/teachers
func (h *DepartmentHandler) HandleTeachers(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var teachers []model.User
	if h.teacherProvider != nil {
		teachers = h.teacherProvider()
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(teachers)
}
