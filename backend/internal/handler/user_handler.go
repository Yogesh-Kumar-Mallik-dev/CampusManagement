package handler

import (
	"encoding/json"
	"net/http"
	"time"

	"campus/backend/internal/idgen"
	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

type UserHandler struct {
	idGen       *idgen.IDService
	permService *service.PermissionService
}

func NewUserHandler(idGen *idgen.IDService, permService *service.PermissionService) *UserHandler {
	return &UserHandler{
		idGen:       idGen,
		permService: permService,
	}
}

type CreateStudentRequest struct {
	FirstName              string `json:"first_name"`
	LastName               string `json:"last_name"`
	Email                  string `json:"email"`
	PersonalEmail          string `json:"personal_email"`
	Phone                  string `json:"phone"`
	AdmissionYear          int    `json:"admission_year"`
	EntryType              string `json:"entry_type"` // 'regular', 'lateral', 'transfer'
	Program                string `json:"program"`    // 'btech', 'mtech', 'phd'
	AdmissionApplicationNo string `json:"admission_application_no"`
}

func (h *UserHandler) CreateStudent(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req CreateStudentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
		return
	}

	handle, err := h.idGen.NextStudentID(r.Context(), req.FirstName, req.AdmissionYear, req.EntryType, req.Program)
	if err != nil {
		http.Error(w, "Failed to generate campus handle: "+err.Error(), http.StatusInternalServerError)
		return
	}

	now := time.Now().UTC()
	user := model.User{
		BaseSyncModel: model.BaseSyncModel{
			ID:        "usr-" + handle,
			CreatedAt: now,
			UpdatedAt: now,
		},
		CampusHandle:           handle,
		FirstName:              req.FirstName,
		LastName:               req.LastName,
		Email:                  req.Email,
		PersonalEmail:          req.PersonalEmail,
		Phone:                  req.Phone,
		Archetype:              model.ArchetypeStudent,
		AdmissionApplicationNo: req.AdmissionApplicationNo,
		IsActive:               true,
	}

	profile := model.StudentProfile{
		UserID:          user.ID,
		AdmissionYear:   req.AdmissionYear,
		EntryType:       req.EntryType,
		Program:         req.Program,
		CurrentSemester: 1,
		BatchYear:       req.AdmissionYear + 4,
	}

	resp := map[string]interface{}{
		"user":    user,
		"profile": profile,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(resp)
}

type CreateEmployeeRequest struct {
	FirstName      string `json:"first_name"`
	LastName       string `json:"last_name"`
	Email          string `json:"email"`
	PersonalEmail  string `json:"personal_email"`
	Phone          string `json:"phone"`
	JoiningYear    int    `json:"joining_year"`
	EmploymentType string `json:"employment_type"` // 'permanent', 'contract', 'visiting'

	// Academic info (if applicable)
	IsAcademic    bool     `json:"is_academic"`
	AcademicRank  string   `json:"academic_rank,omitempty"`
	CabinLocation string   `json:"cabin_location,omitempty"`
	Departments   []string `json:"department_affiliations,omitempty"`

	// Administrative info (if applicable)
	IsAdministrative bool   `json:"is_administrative"`
	PrimaryUnit      string `json:"primary_unit,omitempty"`
	Designation      string `json:"designation,omitempty"`
	OfficeLocation   string `json:"office_location,omitempty"`
}

func (h *UserHandler) CreateEmployee(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req CreateEmployeeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid payload", http.StatusBadRequest)
		return
	}

	handle, err := h.idGen.NextEmployeeID(r.Context(), req.FirstName, req.JoiningYear)
	if err != nil {
		http.Error(w, "Failed to generate employee handle: "+err.Error(), http.StatusInternalServerError)
		return
	}

	now := time.Now().UTC()
	user := model.User{
		BaseSyncModel: model.BaseSyncModel{
			ID:        "usr-" + handle,
			CreatedAt: now,
			UpdatedAt: now,
		},
		CampusHandle:  handle,
		FirstName:     req.FirstName,
		LastName:      req.LastName,
		Email:         req.Email,
		PersonalEmail: req.PersonalEmail,
		Phone:         req.Phone,
		Archetype:     model.ArchetypeEmployee,
		IsActive:      true,
	}

	empRecord := model.EmployeeRecord{
		UserID:           user.ID,
		JoiningDate:      now,
		EmploymentType:   req.EmploymentType,
		IsAcademic:       req.IsAcademic,
		IsAdministrative: req.IsAdministrative,
	}

	resp := map[string]interface{}{
		"user":            user,
		"employee_record": empRecord,
	}

	if req.IsAcademic {
		resp["academic_profile"] = model.AcademicProfile{
			UserID:        user.ID,
			AcademicRank:  req.AcademicRank,
			CabinLocation: req.CabinLocation,
			Departments:   req.Departments,
		}
	}

	if req.IsAdministrative {
		resp["administrative_profile"] = model.AdministrativeProfile{
			UserID:         user.ID,
			PrimaryUnit:    req.PrimaryUnit,
			Designation:    req.Designation,
			OfficeLocation: req.OfficeLocation,
		}
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(resp)
}

type AssignRoleRequest struct {
	UserID     string     `json:"user_id"`
	RoleCode   string     `json:"role_code"`
	ScopeCode  string     `json:"scope_code"`
	ValidUntil *time.Time `json:"valid_until,omitempty"`
}

func (h *UserHandler) AssignRole(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req AssignRoleRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid payload", http.StatusBadRequest)
		return
	}

	if err := h.permService.AssignRole(r.Context(), req.UserID, req.RoleCode, req.ScopeCode, req.ValidUntil); err != nil {
		http.Error(w, "Failed assigning role: "+err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{
		"status":  "success",
		"message": "Role assigned successfully",
	})
}

func (h *UserHandler) CheckPermission(w http.ResponseWriter, r *http.Request) {
	userID := r.URL.Query().Get("user_id")
	action := r.URL.Query().Get("action")
	scope := r.URL.Query().Get("scope")

	allowed, reason := h.permService.Can(r.Context(), userID, action, scope)

	resp := model.PermissionCheckResponse{
		Allowed:   allowed,
		Reason:    reason,
		ScopeUsed: scope,
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}
