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

// HandleSubjects handles GET and POST for /api/v1/academics/subjects
func (h *DepartmentHandler) HandleSubjects(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		subjects, err := h.academicService.ListSubjects(r.Context())
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(subjects)

	case http.MethodPost:
		var req model.Subject
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
			return
		}
		if strings.TrimSpace(req.Name) == "" {
			http.Error(w, "Subject name is required", http.StatusBadRequest)
			return
		}
		created, err := h.academicService.CreateSubject(r.Context(), req)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(created)

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// HandleSubjectSyllabus handles GET (audit trail) and POST (revise syllabus) for /api/v1/academics/subjects/syllabus
func (h *DepartmentHandler) HandleSubjectSyllabus(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		subjectID := r.URL.Query().Get("subject_id")
		if subjectID == "" {
			subjectID = r.URL.Query().Get("id")
		}
		if subjectID == "" {
			http.Error(w, "subject_id parameter is required", http.StatusBadRequest)
			return
		}

		auditTrail, err := h.academicService.GetSubjectSyllabusAuditTrail(r.Context(), subjectID)
		if err != nil {
			http.Error(w, err.Error(), http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(auditTrail)

	case http.MethodPost:
		var req model.ReviseSyllabusRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
			return
		}

		if strings.TrimSpace(req.SubjectID) == "" {
			http.Error(w, "subject_id is required", http.StatusBadRequest)
			return
		}
		if strings.TrimSpace(req.RevisionCode) == "" {
			http.Error(w, "revision_code is required", http.StatusBadRequest)
			return
		}
		if strings.TrimSpace(req.Content) == "" {
			http.Error(w, "content is required", http.StatusBadRequest)
			return
		}

		revised, err := h.academicService.ReviseSyllabus(r.Context(), req)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(revised)

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
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

// HandleSections handles GET and POST for /api/v1/academics/sections
func (h *DepartmentHandler) HandleSections(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		id := r.URL.Query().Get("id")
		if id != "" {
			detail, err := h.academicService.GetSectionDetail(r.Context(), id, h.userResolver, nil)
			if err != nil {
				http.Error(w, err.Error(), http.StatusNotFound)
				return
			}
			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode(detail)
			return
		}

		sections, err := h.academicService.ListSections(r.Context())
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(sections)

	case http.MethodPost:
		var req model.CreateSectionRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
			return
		}
		if strings.TrimSpace(req.Name) == "" || len(req.ProgramIDs) == 0 {
			http.Error(w, "Section name and at least one associated program are required", http.StatusBadRequest)
			return
		}

		created, err := h.academicService.CreateSection(r.Context(), req)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(created)

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// HandleAssignStudentToSection handles POST /api/v1/academics/sections/assign-student
func (h *DepartmentHandler) HandleAssignStudentToSection(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var payload struct {
		StudentID string `json:"student_id"`
		SectionID string `json:"section_id"`
		ProgramID string `json:"program_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
		return
	}

	if payload.StudentID == "" || payload.SectionID == "" {
		http.Error(w, "StudentID and SectionID are required", http.StatusBadRequest)
		return
	}

	if err := h.academicService.AssignStudentToSection(r.Context(), payload.StudentID, payload.SectionID, payload.ProgramID); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"success":    true,
		"student_id": payload.StudentID,
		"section_id": payload.SectionID,
		"program_id": payload.ProgramID,
	})
}

// HandleTransferStudentSection handles POST /api/v1/academics/sections/transfer-student
func (h *DepartmentHandler) HandleTransferStudentSection(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var payload struct {
		StudentID       string `json:"student_id"`
		TargetSectionID string `json:"target_section_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
		return
	}

	if payload.StudentID == "" || payload.TargetSectionID == "" {
		http.Error(w, "student_id and target_section_id are required", http.StatusBadRequest)
		return
	}

	if err := h.academicService.TransferStudentSection(r.Context(), payload.StudentID, payload.TargetSectionID); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"success":           true,
		"student_id":        payload.StudentID,
		"target_section_id": payload.TargetSectionID,
	})
}

// HandleMergeSectionCohorts handles POST /api/v1/academics/sections/merge
func (h *DepartmentHandler) HandleMergeSectionCohorts(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var payload struct {
		SourceSectionID string `json:"source_section_id"`
		TargetSectionID string `json:"target_section_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
		return
	}

	if payload.SourceSectionID == "" || payload.TargetSectionID == "" {
		http.Error(w, "source_section_id and target_section_id are required", http.StatusBadRequest)
		return
	}

	count, err := h.academicService.MergeSectionCohorts(r.Context(), payload.SourceSectionID, payload.TargetSectionID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"success":           true,
		"students_migrated": count,
		"source_section_id": payload.SourceSectionID,
		"target_section_id": payload.TargetSectionID,
	})
}

// HandleLabBatches handles GET and POST for /api/v1/academics/sections/batches
func (h *DepartmentHandler) HandleLabBatches(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		sectionID := r.URL.Query().Get("section_id")
		if sectionID == "" {
			http.Error(w, "section_id query param is required", http.StatusBadRequest)
			return
		}

		batches, err := h.academicService.GetSectionLabBatches(r.Context(), sectionID)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(batches)

	case http.MethodPost:
		var req model.CreateLabBatchRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
			return
		}
		if req.SectionID == "" || strings.TrimSpace(req.Name) == "" {
			http.Error(w, "section_id and name are required", http.StatusBadRequest)
			return
		}

		batch, err := h.academicService.CreateLabBatch(r.Context(), req)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(batch)

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// HandleAutoPartitionBatches handles POST /api/v1/academics/sections/batches/auto-partition
func (h *DepartmentHandler) HandleAutoPartitionBatches(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req model.AutoPartitionBatchesRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
		return
	}
	if req.SectionID == "" {
		http.Error(w, "section_id is required", http.StatusBadRequest)
		return
	}

	batches, err := h.academicService.AutoPartitionLabBatches(r.Context(), req)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(batches)
}

// HandleAssignStudentBatch handles POST /api/v1/academics/sections/batches/assign-student
func (h *DepartmentHandler) HandleAssignStudentBatch(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var payload struct {
		BatchID   string `json:"batch_id"`
		StudentID string `json:"student_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
		return
	}
	if payload.BatchID == "" || payload.StudentID == "" {
		http.Error(w, "batch_id and student_id are required", http.StatusBadRequest)
		return
	}

	if err := h.academicService.AssignStudentToLabBatch(r.Context(), payload.BatchID, payload.StudentID); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"success":    true,
		"batch_id":   payload.BatchID,
		"student_id": payload.StudentID,
	})
}

// HandleFacultyAllocations handles GET, POST, and DELETE for /api/v1/academics/allocations
func (h *DepartmentHandler) HandleFacultyAllocations(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		sectionID := r.URL.Query().Get("section_id")
		if sectionID == "" {
			http.Error(w, "section_id query param is required", http.StatusBadRequest)
			return
		}

		allocs, err := h.academicService.GetSectionFacultyAllocations(r.Context(), sectionID)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(allocs)

	case http.MethodPost:
		var req model.AssignFacultyAllocationRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
			return
		}
		if req.SectionID == "" || req.SubjectID == "" || req.TeacherID == "" {
			http.Error(w, "section_id, subject_id, and teacher_id are required", http.StatusBadRequest)
			return
		}

		alloc, err := h.academicService.AssignFacultyAllocation(r.Context(), req, h.userResolver)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(alloc)

	case http.MethodDelete:
		id := r.URL.Query().Get("id")
		if id == "" {
			http.Error(w, "id query param is required", http.StatusBadRequest)
			return
		}
		if err := h.academicService.RemoveFacultyAllocation(r.Context(), id); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]interface{}{
			"success": true,
			"id":      id,
		})

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// HandleFacultyWorkload handles GET /api/v1/academics/faculty/workload
func (h *DepartmentHandler) HandleFacultyWorkload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	teacherID := r.URL.Query().Get("teacher_id")
	if teacherID != "" {
		summary, err := h.academicService.GetFacultyWorkloadSummary(r.Context(), teacherID, h.userResolver)
		if err != nil {
			http.Error(w, err.Error(), http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(summary)
		return
	}

	summaries, err := h.academicService.GetAllFacultyWorkloadSummaries(r.Context(), h.userResolver, h.teacherProvider)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(summaries)
}

