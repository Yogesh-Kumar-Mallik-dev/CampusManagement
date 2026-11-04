package handler

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	"campus/backend/internal/idgen"
	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

type UserHandler struct {
	idGen       *idgen.IDService
	permService *service.PermissionService

	mu                 sync.RWMutex
	users              map[string]model.User // Key: user.ID
	handleToID         map[string]string     // Key: campus_handle -> user.ID
	studentProfiles    map[string]model.StudentProfile
	employeeRecords    map[string]model.EmployeeRecord
	academicProfiles   map[string]model.AcademicProfile
	adminProfiles      map[string]model.AdministrativeProfile
	contractorProfiles map[string]model.ContractorProfile
}

func NewUserHandler(idGen *idgen.IDService, permService *service.PermissionService) *UserHandler {
	h := &UserHandler{
		idGen:              idGen,
		permService:        permService,
		users:              make(map[string]model.User),
		handleToID:         make(map[string]string),
		studentProfiles:    make(map[string]model.StudentProfile),
		employeeRecords:    make(map[string]model.EmployeeRecord),
		academicProfiles:   make(map[string]model.AcademicProfile),
		adminProfiles:      make(map[string]model.AdministrativeProfile),
		contractorProfiles: make(map[string]model.ContractorProfile),
	}

	h.seedDefaultUsers()
	return h
}

func (h *UserHandler) seedDefaultUsers() {
	now := time.Now().UTC()

	// 1. Student Harish Kumar
	harishHandle := "harish_2025_l_btech_1"
	harishID := "usr-" + harishHandle
	h.users[harishID] = model.User{
		BaseSyncModel: model.BaseSyncModel{
			ID:        harishID,
			CreatedAt: now.Add(-60 * 24 * time.Hour),
			UpdatedAt: now,
		},
		CampusHandle:           harishHandle,
		FirstName:              "Harish",
		LastName:               "Kumar",
		Email:                  "harish_2025_l_btech_1@campus.edu",
		PersonalEmail:          "harish.kumar@example.com",
		Phone:                  "+91 98765 43210",
		Archetype:              model.ArchetypeStudent,
		AdmissionApplicationNo: "APP-2025-0819",
		UniversityRollNo:       "2025-CS-042",
		UniversityRegNo:        "REG-2025-9921",
		IsActive:               true,
		Status:                 "active",
	}
	h.handleToID[harishHandle] = harishID
	h.studentProfiles[harishID] = model.StudentProfile{
		UserID:          harishID,
		AdmissionYear:   2025,
		EntryType:       "lateral",
		Program:         "btech",
		CurrentSemester: 3,
		BatchYear:       2029,
	}

	// 2. Employee Dr. Priya Nair (Dual-track Academic & Administrative)
	priyaHandle := "priya_2024_emp_1"
	priyaID := "usr-" + priyaHandle
	h.users[priyaID] = model.User{
		BaseSyncModel: model.BaseSyncModel{
			ID:        priyaID,
			CreatedAt: now.Add(-300 * 24 * time.Hour),
			UpdatedAt: now,
		},
		CampusHandle:     priyaHandle,
		FirstName:        "Dr. Priya",
		LastName:         "Nair",
		Email:            "priya_2024_emp_1@campus.edu",
		PersonalEmail:    "p.nair@academic-research.org",
		Phone:            "+91 98111 22334",
		Archetype:        model.ArchetypeEmployee,
		UniversityRollNo: "EMP-2024-0012",
		IsActive:         true,
		Status:           "active",
	}
	h.handleToID[priyaHandle] = priyaID
	h.employeeRecords[priyaID] = model.EmployeeRecord{
		UserID:           priyaID,
		JoiningDate:      now.Add(-300 * 24 * time.Hour),
		EmployeeCode:     "FAC-CS-012",
		EmploymentType:   "permanent",
		IsAcademic:       true,
		IsAdministrative: true,
	}
	h.academicProfiles[priyaID] = model.AcademicProfile{
		UserID:          priyaID,
		AcademicRank:    "Professor",
		CabinLocation:   "LH-302, Academic Block B",
		GoogleScholarID: "priya_nair_iitb",
		ResearchAreas:   []string{"Distributed Systems", "Cloud Computing", "Formal Verification"},
		Departments:     []string{"dept:cse"},
	}
	h.adminProfiles[priyaID] = model.AdministrativeProfile{
		UserID:         priyaID,
		PrimaryUnit:    "unit:student_affairs",
		Designation:    "Dean of Student Affairs",
		OfficeLocation: "Administrative Complex Room 104",
	}

	// 3. Employee Ramesh Singh (Administrative Operations)
	rameshHandle := "ramesh_2023_emp_1"
	rameshID := "usr-" + rameshHandle
	h.users[rameshID] = model.User{
		BaseSyncModel: model.BaseSyncModel{
			ID:        rameshID,
			CreatedAt: now.Add(-500 * 24 * time.Hour),
			UpdatedAt: now,
		},
		CampusHandle:     rameshHandle,
		FirstName:        "Ramesh",
		LastName:         "Singh",
		Email:            "ramesh_2023_emp_1@campus.edu",
		PersonalEmail:    "ramesh.singh@campus-ops.net",
		Phone:            "+91 97222 33445",
		Archetype:        model.ArchetypeEmployee,
		UniversityRollNo: "EMP-2023-0089",
		IsActive:         true,
		Status:           "active",
	}
	h.handleToID[rameshHandle] = rameshID
	h.employeeRecords[rameshID] = model.EmployeeRecord{
		UserID:           rameshID,
		JoiningDate:      now.Add(-500 * 24 * time.Hour),
		EmployeeCode:     "ADM-SEC-089",
		EmploymentType:   "permanent",
		IsAcademic:       false,
		IsAdministrative: true,
	}
	h.adminProfiles[rameshID] = model.AdministrativeProfile{
		UserID:         rameshID,
		PrimaryUnit:    "unit:security",
		Designation:    "Chief Security Officer",
		OfficeLocation: "Main Gate Security HQ",
	}

	// 4. Sample Discontinued User: Vikram Malhotra (Graduated Alumnus)
	vikramHandle := "vikram_2021_r_btech_1"
	vikramID := "usr-" + vikramHandle
	discontinuedTime := now.Add(-90 * 24 * time.Hour)
	h.users[vikramID] = model.User{
		BaseSyncModel: model.BaseSyncModel{
			ID:        vikramID,
			CreatedAt: now.Add(-4 * 365 * 24 * time.Hour),
			UpdatedAt: discontinuedTime,
		},
		CampusHandle:           vikramHandle,
		FirstName:              "Vikram",
		LastName:               "Malhotra",
		Email:                  "vikram_2021_r_btech_1@campus.edu",
		PersonalEmail:          "vikram.malhotra@alumni.org",
		Phone:                  "+91 99000 11223",
		Archetype:              model.ArchetypeStudent,
		AdmissionApplicationNo: "APP-2021-0044",
		UniversityRollNo:       "2021-CS-001",
		IsActive:               false,
		Status:                 "graduated",
		DiscontinuationReason:  "Graduated Class of 2025 (B.Tech CSE with First Class Honors)",
		DiscontinuedAt:         &discontinuedTime,
		DiscontinuedBy:         "usr-priya_2024_emp_1",
	}
	h.handleToID[vikramHandle] = vikramID
	h.studentProfiles[vikramID] = model.StudentProfile{
		UserID:          vikramID,
		AdmissionYear:   2021,
		EntryType:       "regular",
		Program:         "btech",
		CurrentSemester: 8,
		BatchYear:       2025,
		SectionScope:    "sec:cse-4b",
		AdvisorName:     "Dr. Priya Nair",
	}

	// 5. Contractor / External: Mukesh Verma (Sodexo Campus Dining Lead)
	mukeshHandle := "mukesh_2025_ext_1"
	mukeshID := "usr-" + mukeshHandle
	mukeshExpiry := now.Add(300 * 24 * time.Hour)
	h.users[mukeshID] = model.User{
		BaseSyncModel: model.BaseSyncModel{
			ID:        mukeshID,
			CreatedAt: now.Add(-40 * 24 * time.Hour),
			UpdatedAt: now,
		},
		CampusHandle:     mukeshHandle,
		FirstName:        "Mukesh",
		LastName:         "Verma",
		Email:            "mukesh_2025_ext_1@campus.edu",
		PersonalEmail:    "mukesh.verma@sodexo-dining.com",
		Phone:            "+91 98333 44556",
		Archetype:        model.ArchetypeExternal,
		UniversityRollNo: "GP-2025-0891",
		IsActive:         true,
		Status:           "active",
	}
	h.handleToID[mukeshHandle] = mukeshID
	h.contractorProfiles[mukeshID] = model.ContractorProfile{
		UserID:             mukeshID,
		OnboardingYear:     2025,
		VendorOrganization: "Sodexo Campus Dining",
		ServiceType:        "canteen",
		ContractExpiresAt:  &mukeshExpiry,
		GatePassID:         "GP-2025-0891",
		SupervisorName:     "Anil Kapoor",
		SupervisorPhone:    "+91 98222 11000",
		PermittedScopes:    []string{"gate:main", "building:canteen"},
	}

	// Seed default roles into permission service if available
	if h.permService != nil {
		_ = h.permService.AssignRole(nil, harishID, "student_base", "sec:cse-3a", nil)
		_ = h.permService.AssignRole(nil, harishID, "club_president", "club:robotics", nil)
		_ = h.permService.AssignRole(nil, priyaID, "hod", "dept:cse", nil)
		_ = h.permService.AssignRole(nil, mukeshID, "vendor_staff", "building:canteen", nil)
	}
}

type CreateStudentRequest struct {
	FirstName              string `json:"first_name"`
	LastName               string `json:"last_name"`
	Email                  string `json:"email"`
	PersonalEmail          string `json:"personal_email,omitempty"`
	Phone                  string `json:"phone,omitempty"`
	AdmissionYear          int    `json:"admission_year"`
	EntryType              string `json:"entry_type"` // 'regular', 'lateral', 'transfer'
	Program                string `json:"program"`    // 'btech', 'mtech', 'phd'
	AdmissionApplicationNo string `json:"admission_application_no,omitempty"`
	UniversityRollNo       string `json:"university_roll_no,omitempty"`
	UniversityRegNo        string `json:"university_reg_no,omitempty"`
	CurrentSemester        int    `json:"current_semester,omitempty"`
	BatchYear              int    `json:"batch_year,omitempty"`
	SectionScope           string `json:"section_scope,omitempty"`
	AdvisorName            string `json:"advisor_name,omitempty"`
	HostelBlock            string `json:"hostel_block,omitempty"`
	RoomNumber             string `json:"room_number,omitempty"`
	EmergencyContactName   string `json:"emergency_contact_name,omitempty"`
	EmergencyContactPhone  string `json:"emergency_contact_phone,omitempty"`
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

	batchYear := req.BatchYear
	if batchYear <= 0 {
		batchYear = req.AdmissionYear + 4
	}
	currentSemester := req.CurrentSemester
	if currentSemester <= 0 {
		currentSemester = 1
	}
	sectionScope := req.SectionScope
	if sectionScope == "" {
		sectionScope = "sec:" + strings.ToLower(req.Program) + "-1a"
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
		UniversityRollNo:       req.UniversityRollNo,
		UniversityRegNo:        req.UniversityRegNo,
		IsActive:               true,
		Status:                 "active",
	}

	profile := model.StudentProfile{
		UserID:                user.ID,
		AdmissionYear:         req.AdmissionYear,
		EntryType:             req.EntryType,
		Program:               req.Program,
		CurrentSemester:       currentSemester,
		BatchYear:             batchYear,
		SectionScope:          sectionScope,
		AdvisorName:           req.AdvisorName,
		HostelBlock:           req.HostelBlock,
		RoomNumber:            req.RoomNumber,
		EmergencyContactName:  req.EmergencyContactName,
		EmergencyContactPhone: req.EmergencyContactPhone,
	}

	h.mu.Lock()
	h.users[user.ID] = user
	h.handleToID[handle] = user.ID
	h.studentProfiles[user.ID] = profile
	h.mu.Unlock()

	// Assign baseline student role
	if h.permService != nil {
		_ = h.permService.AssignRole(r.Context(), user.ID, "student_base", sectionScope, nil)
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
	PersonalEmail  string `json:"personal_email,omitempty"`
	Phone          string `json:"phone,omitempty"`
	JoiningYear    int    `json:"joining_year"`
	EmployeeCode   string `json:"employee_code,omitempty"`
	EmploymentType string `json:"employment_type"` // 'permanent', 'contract', 'visiting'

	// Academic info (if applicable)
	IsAcademic      bool     `json:"is_academic"`
	AcademicRank    string   `json:"academic_rank,omitempty"`
	CabinLocation   string   `json:"cabin_location,omitempty"`
	GoogleScholarID string   `json:"google_scholar_id,omitempty"`
	ResearchAreas   []string `json:"research_areas,omitempty"`
	Departments     []string `json:"department_affiliations,omitempty"`

	// Administrative info (if applicable)
	IsAdministrative bool   `json:"is_administrative"`
	PrimaryUnit      string `json:"primary_unit,omitempty"`
	Designation      string `json:"designation,omitempty"`
	OfficeLocation   string `json:"office_location,omitempty"`

	EmergencyContactName  string `json:"emergency_contact_name,omitempty"`
	EmergencyContactPhone string `json:"emergency_contact_phone,omitempty"`
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
		CampusHandle:     handle,
		FirstName:        req.FirstName,
		LastName:         req.LastName,
		Email:            req.Email,
		PersonalEmail:    req.PersonalEmail,
		Phone:            req.Phone,
		Archetype:        model.ArchetypeEmployee,
		UniversityRollNo: req.EmployeeCode,
		IsActive:         true,
		Status:           "active",
	}

	empRecord := model.EmployeeRecord{
		UserID:                user.ID,
		JoiningDate:           now,
		EmployeeCode:          req.EmployeeCode,
		EmploymentType:        req.EmploymentType,
		IsAcademic:            req.IsAcademic,
		IsAdministrative:      req.IsAdministrative,
		EmergencyContactName:  req.EmergencyContactName,
		EmergencyContactPhone: req.EmergencyContactPhone,
	}

	h.mu.Lock()
	h.users[user.ID] = user
	h.handleToID[handle] = user.ID
	h.employeeRecords[user.ID] = empRecord

	var acadProfile *model.AcademicProfile
	if req.IsAcademic {
		ap := model.AcademicProfile{
			UserID:          user.ID,
			AcademicRank:    req.AcademicRank,
			CabinLocation:   req.CabinLocation,
			GoogleScholarID: req.GoogleScholarID,
			ResearchAreas:   req.ResearchAreas,
			Departments:     req.Departments,
		}
		h.academicProfiles[user.ID] = ap
		acadProfile = &ap
	}

	var adminProfile *model.AdministrativeProfile
	if req.IsAdministrative {
		ad := model.AdministrativeProfile{
			UserID:         user.ID,
			PrimaryUnit:    req.PrimaryUnit,
			Designation:    req.Designation,
			OfficeLocation: req.OfficeLocation,
		}
		h.adminProfiles[user.ID] = ad
		adminProfile = &ad
	}
	h.mu.Unlock()

	// Assign roles based on capability
	if h.permService != nil {
		if req.IsAcademic {
			scope := "dept:cse"
			if len(req.Departments) > 0 && req.Departments[0] != "" {
				scope = req.Departments[0]
			}
			_ = h.permService.AssignRole(r.Context(), user.ID, "faculty", scope, nil)
		}
		if req.IsAdministrative {
			unitScope := req.PrimaryUnit
			if unitScope == "" {
				unitScope = "unit:general"
			}
			_ = h.permService.AssignRole(r.Context(), user.ID, "staff", unitScope, nil)
		}
	}

	resp := map[string]interface{}{
		"user":                   user,
		"employee_record":        empRecord,
		"academic_profile":       acadProfile,
		"administrative_profile": adminProfile,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(resp)
}

type CreateContractorRequest struct {
	FirstName          string     `json:"first_name"`
	LastName           string     `json:"last_name"`
	Email              string     `json:"email"`
	PersonalEmail      string     `json:"personal_email,omitempty"`
	Phone              string     `json:"phone,omitempty"`
	OnboardingYear     int        `json:"onboarding_year"`
	VendorOrganization string     `json:"vendor_organization"`
	ServiceType        string     `json:"service_type"` // 'canteen', 'mess', 'cleaning', 'security', 'transport', 'maintenance'
	ContractExpiresAt  *time.Time `json:"contract_expires_at,omitempty"`
	GatePassID         string     `json:"gate_pass_id,omitempty"`
	SupervisorName     string     `json:"supervisor_name,omitempty"`
	SupervisorPhone    string     `json:"supervisor_phone,omitempty"`
	PermittedScopes    []string   `json:"permitted_scopes,omitempty"`
}

func (h *UserHandler) CreateContractor(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req CreateContractorRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid payload", http.StatusBadRequest)
		return
	}

	if req.OnboardingYear <= 0 {
		req.OnboardingYear = time.Now().Year()
	}

	handle, err := h.idGen.NextExternalID(r.Context(), req.FirstName, req.OnboardingYear)
	if err != nil {
		http.Error(w, "Failed to generate contractor handle: "+err.Error(), http.StatusInternalServerError)
		return
	}

	gatePassID := req.GatePassID
	if gatePassID == "" {
		gatePassID = fmt.Sprintf("GP-%d-%s", req.OnboardingYear, handle)
	}

	now := time.Now().UTC()
	user := model.User{
		BaseSyncModel: model.BaseSyncModel{
			ID:        "usr-" + handle,
			CreatedAt: now,
			UpdatedAt: now,
		},
		CampusHandle:     handle,
		FirstName:        req.FirstName,
		LastName:         req.LastName,
		Email:            req.Email,
		PersonalEmail:    req.PersonalEmail,
		Phone:            req.Phone,
		Archetype:        model.ArchetypeExternal,
		UniversityRollNo: gatePassID,
		IsActive:         true,
		Status:           "active",
	}

	contractorProfile := model.ContractorProfile{
		UserID:             user.ID,
		OnboardingYear:     req.OnboardingYear,
		VendorOrganization: req.VendorOrganization,
		ServiceType:        req.ServiceType,
		ContractExpiresAt:  req.ContractExpiresAt,
		GatePassID:         gatePassID,
		SupervisorName:     req.SupervisorName,
		SupervisorPhone:    req.SupervisorPhone,
		PermittedScopes:    req.PermittedScopes,
	}

	h.mu.Lock()
	h.users[user.ID] = user
	h.handleToID[handle] = user.ID
	h.contractorProfiles[user.ID] = contractorProfile
	h.mu.Unlock()

	// Assign contractor / vendor role
	if h.permService != nil {
		scope := "gate:main"
		if len(req.PermittedScopes) > 0 && req.PermittedScopes[0] != "" {
			scope = req.PermittedScopes[0]
		}
		_ = h.permService.AssignRole(r.Context(), user.ID, "vendor_staff", scope, nil)
	}

	resp := map[string]interface{}{
		"user":               user,
		"contractor_profile": contractorProfile,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(resp)
}

// HandleUsers handles listing users with filters
func (h *UserHandler) HandleUsers(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	archetypeFilter := strings.TrimSpace(strings.ToLower(r.URL.Query().Get("archetype")))
	statusFilter := strings.TrimSpace(strings.ToLower(r.URL.Query().Get("status")))
	searchQuery := strings.TrimSpace(strings.ToLower(r.URL.Query().Get("search")))

	h.mu.RLock()
	defer h.mu.RUnlock()

	var result []model.User
	for _, u := range h.users {
		// Archetype filter
		if archetypeFilter != "" && archetypeFilter != "all" {
			if string(u.Archetype) != archetypeFilter {
				continue
			}
		}

		// Status filter
		if statusFilter != "" && statusFilter != "all" {
			if statusFilter == "inactive" {
				if u.IsActive {
					continue
				}
			} else if strings.ToLower(u.Status) != statusFilter {
				continue
			}
		}

		// Search query filter (matches handle, first_name, last_name, email)
		if searchQuery != "" {
			nameMatch := strings.Contains(strings.ToLower(u.FirstName+" "+u.LastName), searchQuery)
			handleMatch := strings.Contains(strings.ToLower(u.CampusHandle), searchQuery)
			emailMatch := strings.Contains(strings.ToLower(u.Email), searchQuery)
			rollMatch := strings.Contains(strings.ToLower(u.UniversityRollNo), searchQuery)
			if !nameMatch && !handleMatch && !emailMatch && !rollMatch {
				continue
			}
		}

		result = append(result, u)
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(result)
}

// GetUserProfile returns complete aggregate details for a user
func (h *UserHandler) GetUserProfile(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	targetID := strings.TrimSpace(r.URL.Query().Get("id"))
	targetHandle := strings.TrimSpace(r.URL.Query().Get("handle"))

	h.mu.RLock()
	defer h.mu.RUnlock()

	var user model.User
	var found bool

	if targetID != "" {
		user, found = h.users[targetID]
	}
	if !found && targetHandle != "" {
		if id, exists := h.handleToID[targetHandle]; exists {
			user, found = h.users[id]
		}
	}

	if !found {
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	profileResp := model.UserProfileResponse{
		User: user,
	}

	if sp, exists := h.studentProfiles[user.ID]; exists {
		profileResp.StudentProfile = &sp
	}
	if er, exists := h.employeeRecords[user.ID]; exists {
		profileResp.EmployeeRecord = &er
	}
	if ap, exists := h.academicProfiles[user.ID]; exists {
		profileResp.AcademicProfile = &ap
	}
	if ad, exists := h.adminProfiles[user.ID]; exists {
		profileResp.AdministrativeProfile = &ad
	}
	if cp, exists := h.contractorProfiles[user.ID]; exists {
		profileResp.ContractorProfile = &cp
	}

	if h.permService != nil {
		profileResp.AssignedRoles = h.permService.GetUserRoles(user.ID)
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(profileResp)
}

type DiscontinueUserRequest struct {
	UserID         string `json:"user_id"`
	Status         string `json:"status"` // 'graduated', 'resigned', 'retired', 'suspended', 'discontinued'
	Reason         string `json:"reason"`
	DiscontinuedBy string `json:"discontinued_by"`
}

// DiscontinueUser marks a user inactive with an audit reason and revokes their active permissions
func (h *UserHandler) DiscontinueUser(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req DiscontinueUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid payload", http.StatusBadRequest)
		return
	}

	if req.UserID == "" {
		http.Error(w, "user_id is required", http.StatusBadRequest)
		return
	}

	cleanStatus := strings.TrimSpace(strings.ToLower(req.Status))
	if cleanStatus == "" {
		cleanStatus = "discontinued"
	}

	h.mu.Lock()
	user, exists := h.users[req.UserID]
	if !exists {
		h.mu.Unlock()
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	now := time.Now().UTC()
	user.IsActive = false
	user.Status = cleanStatus
	user.DiscontinuationReason = req.Reason
	user.DiscontinuedAt = &now
	user.DiscontinuedBy = req.DiscontinuedBy
	user.UpdatedAt = now

	h.users[req.UserID] = user
	h.mu.Unlock()

	// Revoke security permissions
	if h.permService != nil {
		_ = h.permService.RevokeAllUserRoles(r.Context(), user.ID)
	}

	resp := map[string]interface{}{
		"status":  "success",
		"message": "User successfully discontinued and active permissions revoked",
		"user":    user,
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}

type ReactivateUserRequest struct {
	UserID string `json:"user_id"`
}

// ReactivateUser restores an inactive/discontinued user back to active status
func (h *UserHandler) ReactivateUser(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req ReactivateUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid payload", http.StatusBadRequest)
		return
	}

	if req.UserID == "" {
		http.Error(w, "user_id is required", http.StatusBadRequest)
		return
	}

	h.mu.Lock()
	user, exists := h.users[req.UserID]
	if !exists {
		h.mu.Unlock()
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	now := time.Now().UTC()
	user.IsActive = true
	user.Status = "active"
	user.DiscontinuationReason = ""
	user.DiscontinuedAt = nil
	user.UpdatedAt = now

	h.users[req.UserID] = user
	h.mu.Unlock()

	resp := map[string]interface{}{
		"status":  "success",
		"message": "User reactivated successfully",
		"user":    user,
	}

	w.Header().Set("Content-Type", "application/json")
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

// FindUser resolves a user by ID or campus handle
func (h *UserHandler) FindUser(identifier string) (model.User, bool) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	if u, ok := h.users[identifier]; ok {
		return u, true
	}
	if id, ok := h.handleToID[identifier]; ok {
		if u, ok := h.users[id]; ok {
			return u, true
		}
	}
	return model.User{}, false
}

// ListTeachers returns all academic employee users for department assignment
func (h *UserHandler) ListTeachers() []model.User {
	h.mu.RLock()
	defer h.mu.RUnlock()

	var teachers []model.User
	for _, u := range h.users {
		if !u.IsDeleted && u.Archetype == model.ArchetypeEmployee {
			if rec, ok := h.employeeRecords[u.ID]; ok && rec.IsAcademic {
				teachers = append(teachers, u)
			}
		}
	}
	return teachers
}
