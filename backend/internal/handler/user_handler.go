package handler

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	"campus/backend/internal/idgen"
	"campus/backend/internal/model"
	"campus/backend/internal/service"
	"github.com/jackc/pgx/v5/pgxpool"
)

func HashPassword(password string) string {
	hash := sha256.Sum256([]byte("campus_salt_v1:" + password))
	return hex.EncodeToString(hash[:])
}

func VerifyPassword(password, hash string) bool {
	if hash == "" {
		return false
	}
	return HashPassword(password) == hash
}

type UserHandler struct {
	idGen       idgen.IDServiceInterface
	permService service.PermissionServiceInterface
	db          *pgxpool.Pool

	mu                 sync.RWMutex
	users              map[string]model.User // Key: user.ID
	handleToID         map[string]string     // Key: campus_handle -> user.ID
	studentProfiles    map[string]model.StudentProfile
	employeeRecords    map[string]model.EmployeeRecord
	academicProfiles   map[string]model.AcademicProfile
	adminProfiles      map[string]model.AdministrativeProfile
	contractorProfiles map[string]model.ContractorProfile
}

func NewUserHandler(idGen idgen.IDServiceInterface, permService service.PermissionServiceInterface, dbPool ...*pgxpool.Pool) *UserHandler {
	var pool *pgxpool.Pool
	if len(dbPool) > 0 {
		pool = dbPool[0]
	}
	h := &UserHandler{
		idGen:              idGen,
		permService:        permService,
		db:                 pool,
		users:              make(map[string]model.User),
		handleToID:         make(map[string]string),
		studentProfiles:    make(map[string]model.StudentProfile),
		employeeRecords:    make(map[string]model.EmployeeRecord),
		academicProfiles:   make(map[string]model.AcademicProfile),
		adminProfiles:      make(map[string]model.AdministrativeProfile),
		contractorProfiles: make(map[string]model.ContractorProfile),
	}

	h.loadUsersFromDB()
	if len(h.users) == 0 {
		h.seedDefaultUsers()
	}
	return h
}

func (h *UserHandler) loadUsersFromDB() {
	if h.db == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	rows, err := h.db.Query(ctx, `SELECT id, campus_handle, first_name, last_name, email, COALESCE(personal_email, ''), COALESCE(phone, ''), archetype, COALESCE(admission_application_no, ''), COALESCE(university_roll_no, ''), COALESCE(university_reg_no, ''), is_active, status, COALESCE(password_hash, ''), COALESCE(must_change_password, true), created_at, updated_at, is_deleted FROM users WHERE is_deleted = false`)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var u model.User
			var personal, phone, appNo, roll, reg, passHash string
			if err := rows.Scan(&u.ID, &u.CampusHandle, &u.FirstName, &u.LastName, &u.Email, &personal, &phone, &u.Archetype, &appNo, &roll, &reg, &u.IsActive, &u.Status, &passHash, &u.MustChangePassword, &u.CreatedAt, &u.UpdatedAt, &u.IsDeleted); err == nil {
				u.PersonalEmail = personal
				u.Phone = phone
				u.AdmissionApplicationNo = appNo
				u.UniversityRollNo = roll
				u.UniversityRegNo = reg
				if passHash == "" {
					u.PasswordHash = HashPassword(u.CampusHandle)
					u.MustChangePassword = true
				} else {
					u.PasswordHash = passHash
				}
				h.users[u.ID] = u
				h.handleToID[u.CampusHandle] = u.ID
			}
		}
	}

	empRows, err := h.db.Query(ctx, `SELECT user_id, joining_date, COALESCE(employee_code, ''), employment_type, is_academic, is_administrative FROM employee_records`)
	if err == nil {
		defer empRows.Close()
		for empRows.Next() {
			var rec model.EmployeeRecord
			if err := empRows.Scan(&rec.UserID, &rec.JoiningDate, &rec.EmployeeCode, &rec.EmploymentType, &rec.IsAcademic, &rec.IsAdministrative); err == nil {
				h.employeeRecords[rec.UserID] = rec
			}
		}
	}

	stuRows, err := h.db.Query(ctx, `SELECT user_id, admission_year, entry_type, program, current_semester, batch_year FROM student_profiles`)
	if err == nil {
		defer stuRows.Close()
		for stuRows.Next() {
			var sp model.StudentProfile
			if err := stuRows.Scan(&sp.UserID, &sp.AdmissionYear, &sp.EntryType, &sp.Program, &sp.CurrentSemester, &sp.BatchYear); err == nil {
				h.studentProfiles[sp.UserID] = sp
			}
		}
	}

	contRows, err := h.db.Query(ctx, `SELECT user_id, onboarding_year, vendor_organization, service_type, contract_expires_at FROM contractor_profiles`)
	if err == nil {
		defer contRows.Close()
		for contRows.Next() {
			var cp model.ContractorProfile
			if err := contRows.Scan(&cp.UserID, &cp.OnboardingYear, &cp.VendorOrganization, &cp.ServiceType, &cp.ContractExpiresAt); err == nil {
				h.contractorProfiles[cp.UserID] = cp
			}
		}
	}
}

func (h *UserHandler) seedDefaultUsers() {
	now := time.Now().UTC()

	// Campus Administrator - The only pre-seeded institutional account
	adminHandle := "campus_admin"
	adminID := "usr-" + adminHandle
	h.users[adminID] = model.User{
		BaseSyncModel: model.BaseSyncModel{
			ID:        adminID,
			CreatedAt: now.Add(-365 * 24 * time.Hour),
			UpdatedAt: now,
		},
		CampusHandle:     adminHandle,
		FirstName:        "Campus",
		LastName:         "Administrator",
		Email:            "admin@campus.edu",
		PersonalEmail:    "director@campus-governance.org",
		Phone:            "+91 98000 00001",
		Archetype:        model.ArchetypeEmployee,
		UniversityRollNo: "ADM-2023-0001",
		IsActive:         true,
		Status:           "active",
	}
	h.handleToID[adminHandle] = adminID
	adminJoining := now.Add(-365 * 24 * time.Hour)
	h.employeeRecords[adminID] = model.EmployeeRecord{
		UserID:           adminID,
		JoiningDate:      adminJoining,
		EmployeeCode:     "ADM-DIR-001",
		EmploymentType:   "permanent",
		IsAcademic:       false,
		IsAdministrative: true,
	}
	h.adminProfiles[adminID] = model.AdministrativeProfile{
		UserID:         adminID,
		Designation:    "Campus Administrator",
		PrimaryUnit:    "unit:administration",
		OfficeLocation: "Central Admin Tower 501",
	}

	// Seed default roles into permission service if available
	if h.permService != nil {
		_ = h.permService.AssignRole(nil, adminID, "campus_director", "global", nil)
		_ = h.permService.AssignRole(nil, adminID, "admin", "global", nil)
	}

	if h.db != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_, _ = h.db.Exec(ctx, `
			INSERT INTO users (id, campus_handle, first_name, last_name, email, personal_email, phone, archetype, university_roll_no, is_active, status, created_at, updated_at, is_deleted)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, false)
			ON CONFLICT (id) DO NOTHING
		`, adminID, adminHandle, "Campus", "Administrator", "admin@campus.edu", "director@campus-governance.org", "+91 98000 00001", model.ArchetypeEmployee, "ADM-2023-0001", true, "active", now.Add(-365*24*time.Hour), now)
		_, _ = h.db.Exec(ctx, `
			INSERT INTO employee_records (user_id, joining_date, employee_code, employment_type, is_academic, is_administrative)
			VALUES ($1, $2, $3, $4, $5, $6)
			ON CONFLICT (user_id) DO NOTHING
		`, adminID, adminJoining, "ADM-DIR-001", "permanent", false, true)
	}
}

type CreateStudentRequest struct {
	FirstName              string `json:"first_name"`
	LastName               string `json:"last_name"`
	Email                  string `json:"email"`
	PersonalEmail          string `json:"personal_email,omitempty"`
	Phone                  string `json:"phone,omitempty"`
	Gender                 string `json:"gender,omitempty"`
	AcademicName           string `json:"academic_name,omitempty"`
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

	now := time.Now().UTC()
	passHash := HashPassword(handle)
	academicName := strings.TrimSpace(req.AcademicName)
	academicNameSource := ""
	if academicName != "" {
		academicNameSource = "direct_entry"
	}

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
		Gender:                 strings.TrimSpace(req.Gender),
		AcademicName:           academicName,
		EmergencyContactName:   req.EmergencyContactName,
		EmergencyContactPhone:  req.EmergencyContactPhone,
		Archetype:              model.ArchetypeStudent,
		AdmissionApplicationNo: req.AdmissionApplicationNo,
		UniversityRollNo:       req.UniversityRollNo,
		UniversityRegNo:        req.UniversityRegNo,
		IsActive:               true,
		Status:                 "active",
		MustChangePassword:     true,
		PasswordHash:           passHash,
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
		AcademicName:          academicName,
		AcademicNameVerified:  false,
		AcademicNameSource:    academicNameSource,
	}

	h.mu.Lock()
	h.users[user.ID] = user
	h.handleToID[handle] = user.ID
	h.studentProfiles[user.ID] = profile
	h.mu.Unlock()

	if h.db != nil {
		go func() {
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			_, _ = h.db.Exec(ctx, `
				INSERT INTO users (id, campus_handle, first_name, last_name, email, personal_email, phone, archetype, admission_application_no, university_roll_no, university_reg_no, is_active, status, password_hash, must_change_password, created_at, updated_at, is_deleted)
				VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, false)
				ON CONFLICT (id) DO UPDATE SET
					campus_handle = EXCLUDED.campus_handle,
					first_name = EXCLUDED.first_name,
					last_name = EXCLUDED.last_name,
					email = EXCLUDED.email,
					personal_email = EXCLUDED.personal_email,
					phone = EXCLUDED.phone,
					admission_application_no = EXCLUDED.admission_application_no,
					university_roll_no = EXCLUDED.university_roll_no,
					university_reg_no = EXCLUDED.university_reg_no,
					password_hash = EXCLUDED.password_hash,
					must_change_password = EXCLUDED.must_change_password,
					updated_at = EXCLUDED.updated_at
			`, user.ID, user.CampusHandle, user.FirstName, user.LastName, user.Email, user.PersonalEmail, user.Phone, user.Archetype, user.AdmissionApplicationNo, user.UniversityRollNo, user.UniversityRegNo, user.IsActive, user.Status, user.PasswordHash, user.MustChangePassword, user.CreatedAt, user.UpdatedAt)

			_, _ = h.db.Exec(ctx, `
				INSERT INTO student_profiles (user_id, admission_year, entry_type, program, current_semester, batch_year)
				VALUES ($1, $2, $3, $4, $5, $6)
				ON CONFLICT (user_id) DO UPDATE SET
					admission_year = EXCLUDED.admission_year,
					entry_type = EXCLUDED.entry_type,
					program = EXCLUDED.program,
					current_semester = EXCLUDED.current_semester,
					batch_year = EXCLUDED.batch_year
			`, profile.UserID, profile.AdmissionYear, profile.EntryType, profile.Program, profile.CurrentSemester, profile.BatchYear)
		}()
	}

	// Assign baseline student role
	if h.permService != nil {
		roleScope := "global"
		if sectionScope != "" {
			roleScope = sectionScope
		}
		_ = h.permService.AssignRole(r.Context(), user.ID, "student_base", roleScope, nil)
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
	Gender         string `json:"gender,omitempty"`
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
	passHash := HashPassword(handle)
	user := model.User{
		BaseSyncModel: model.BaseSyncModel{
			ID:        "usr-" + handle,
			CreatedAt: now,
			UpdatedAt: now,
		},
		CampusHandle:          handle,
		FirstName:             req.FirstName,
		LastName:              req.LastName,
		Email:                 req.Email,
		PersonalEmail:         req.PersonalEmail,
		Phone:                 req.Phone,
		Gender:                strings.TrimSpace(req.Gender),
		EmergencyContactName:  req.EmergencyContactName,
		EmergencyContactPhone: req.EmergencyContactPhone,
		Archetype:             model.ArchetypeEmployee,
		UniversityRollNo:      req.EmployeeCode,
		IsActive:              true,
		Status:                "active",
		MustChangePassword:    true,
		PasswordHash:          passHash,
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

	if h.db != nil {
		go func() {
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			_, _ = h.db.Exec(ctx, `
				INSERT INTO users (id, campus_handle, first_name, last_name, email, personal_email, phone, archetype, university_roll_no, is_active, status, password_hash, must_change_password, created_at, updated_at, is_deleted)
				VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, false)
				ON CONFLICT (id) DO UPDATE SET
					campus_handle = EXCLUDED.campus_handle,
					first_name = EXCLUDED.first_name,
					last_name = EXCLUDED.last_name,
					email = EXCLUDED.email,
					personal_email = EXCLUDED.personal_email,
					phone = EXCLUDED.phone,
					university_roll_no = EXCLUDED.university_roll_no,
					password_hash = EXCLUDED.password_hash,
					must_change_password = EXCLUDED.must_change_password,
					updated_at = EXCLUDED.updated_at
			`, user.ID, user.CampusHandle, user.FirstName, user.LastName, user.Email, user.PersonalEmail, user.Phone, user.Archetype, user.UniversityRollNo, user.IsActive, user.Status, user.PasswordHash, user.MustChangePassword, user.CreatedAt, user.UpdatedAt)

			_, _ = h.db.Exec(ctx, `
				INSERT INTO employee_records (user_id, joining_date, employee_code, employment_type, is_academic, is_administrative)
				VALUES ($1, $2, $3, $4, $5, $6)
				ON CONFLICT (user_id) DO UPDATE SET
					joining_date = EXCLUDED.joining_date,
					employee_code = EXCLUDED.employee_code,
					employment_type = EXCLUDED.employment_type,
					is_academic = EXCLUDED.is_academic,
					is_administrative = EXCLUDED.is_administrative
			`, empRecord.UserID, empRecord.JoiningDate, empRecord.EmployeeCode, empRecord.EmploymentType, empRecord.IsAcademic, empRecord.IsAdministrative)
		}()
	}

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
				unitScope = "global"
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
	Gender             string     `json:"gender,omitempty"`
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

	now := time.Now().UTC()
	passHash := HashPassword(handle)
	user := model.User{
		BaseSyncModel: model.BaseSyncModel{
			ID:        "usr-" + handle,
			CreatedAt: now,
			UpdatedAt: now,
		},
		CampusHandle:       handle,
		FirstName:          req.FirstName,
		LastName:           req.LastName,
		Email:              req.Email,
		PersonalEmail:      req.PersonalEmail,
		Phone:              req.Phone,
		Gender:             strings.TrimSpace(req.Gender),
		Archetype:          model.ArchetypeExternal,
		UniversityRollNo:   gatePassID,
		IsActive:           true,
		Status:             "active",
		MustChangePassword: true,
		PasswordHash:       passHash,
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

	if h.db != nil {
		go func() {
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			_, _ = h.db.Exec(ctx, `
				INSERT INTO users (id, campus_handle, first_name, last_name, email, personal_email, phone, archetype, university_roll_no, is_active, status, password_hash, must_change_password, created_at, updated_at, is_deleted)
				VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, false)
				ON CONFLICT (id) DO UPDATE SET
					campus_handle = EXCLUDED.campus_handle,
					first_name = EXCLUDED.first_name,
					last_name = EXCLUDED.last_name,
					email = EXCLUDED.email,
					personal_email = EXCLUDED.personal_email,
					phone = EXCLUDED.phone,
					university_roll_no = EXCLUDED.university_roll_no,
					password_hash = EXCLUDED.password_hash,
					must_change_password = EXCLUDED.must_change_password,
					updated_at = EXCLUDED.updated_at
			`, user.ID, user.CampusHandle, user.FirstName, user.LastName, user.Email, user.PersonalEmail, user.Phone, user.Archetype, user.UniversityRollNo, user.IsActive, user.Status, user.PasswordHash, user.MustChangePassword, user.CreatedAt, user.UpdatedAt)

			_, _ = h.db.Exec(ctx, `
				INSERT INTO contractor_profiles (user_id, onboarding_year, vendor_organization, service_type, contract_expires_at)
				VALUES ($1, $2, $3, $4, $5)
				ON CONFLICT (user_id) DO UPDATE SET
					onboarding_year = EXCLUDED.onboarding_year,
					vendor_organization = EXCLUDED.vendor_organization,
					service_type = EXCLUDED.service_type,
					contract_expires_at = EXCLUDED.contract_expires_at
			`, contractorProfile.UserID, contractorProfile.OnboardingYear, contractorProfile.VendorOrganization, contractorProfile.ServiceType, contractorProfile.ContractExpiresAt)
		}()
	}

	// Assign contractor / vendor role
	if h.permService != nil {
		scope := "global"
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
		if user.AcademicName == "" && sp.AcademicName != "" {
			user.AcademicName = sp.AcademicName
			profileResp.User = user
		}
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
		profileResp.Permissions = h.permService.GetUserPermissions(user.ID)
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(profileResp)
}

// UpdateUserProfile updates self-service editable contact fields for a user
func (h *UserHandler) UpdateUserProfile(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req model.UpdateUserProfileRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, fmt.Sprintf("Invalid JSON body: %v", err), http.StatusBadRequest)
		return
	}

	req.UserID = strings.TrimSpace(req.UserID)
	if req.UserID == "" {
		http.Error(w, "user_id is required", http.StatusBadRequest)
		return
	}

	h.mu.Lock()
	defer h.mu.Unlock()

	user, exists := h.users[req.UserID]
	if !exists {
		if id, ok := h.handleToID[req.UserID]; ok {
			user, exists = h.users[id]
		}
	}
	if !exists {
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	if req.PersonalEmail != "" {
		user.PersonalEmail = strings.TrimSpace(req.PersonalEmail)
	}
	if req.Phone != "" {
		user.Phone = strings.TrimSpace(req.Phone)
	}
	if req.EmergencyContactName != "" {
		user.EmergencyContactName = strings.TrimSpace(req.EmergencyContactName)
	}
	if req.EmergencyContactPhone != "" {
		user.EmergencyContactPhone = strings.TrimSpace(req.EmergencyContactPhone)
	}
	if req.BloodGroup != "" {
		user.BloodGroup = strings.TrimSpace(req.BloodGroup)
	}
	if req.Address != "" {
		user.Address = strings.TrimSpace(req.Address)
	}
	if req.Gender != "" {
		user.Gender = strings.TrimSpace(req.Gender)
	}
	if req.AcademicName != "" {
		user.AcademicName = strings.TrimSpace(req.AcademicName)
		if sp, ok := h.studentProfiles[user.ID]; ok {
			sp.AcademicName = user.AcademicName
			if req.AcademicNameSource != "" {
				sp.AcademicNameSource = req.AcademicNameSource
				sp.AcademicNameVerified = (req.AcademicNameSource == "digilocker_class_x" || req.AcademicNameSource == "manual_pdf_upload")
			}
			if req.ClassXDocumentRef != "" {
				sp.ClassXDocumentRef = req.ClassXDocumentRef
			}
			h.studentProfiles[user.ID] = sp
		}
	}
	user.UpdatedAt = time.Now().UTC()

	h.users[user.ID] = user

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(user)
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

// GetUserRoles returns the assigned roles and permission strings for a user
func (h *UserHandler) GetUserRoles(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	targetID := strings.TrimSpace(r.URL.Query().Get("user_id"))
	if targetID == "" {
		targetID = strings.TrimSpace(r.URL.Query().Get("id"))
	}
	targetHandle := strings.TrimSpace(r.URL.Query().Get("handle"))

	h.mu.RLock()
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
	h.mu.RUnlock()

	if !found && targetID != "" {
		user.ID = targetID
		found = true
	}

	if !found {
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	var roles []model.UserRoleAssignment
	var perms []string
	if h.permService != nil {
		roles = h.permService.GetUserRoles(user.ID)
		perms = h.permService.GetUserPermissions(user.ID)
	}

	resp := map[string]interface{}{
		"user_id":     user.ID,
		"roles":       roles,
		"permissions": perms,
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
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

// FindUser resolves a user by ID, campus handle, or email
func (h *UserHandler) FindUser(identifier string) (model.User, bool) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	clean := strings.TrimSpace(strings.ToLower(identifier))
	if u, ok := h.users[clean]; ok {
		return u, true
	}
	if id, ok := h.handleToID[clean]; ok {
		if u, ok := h.users[id]; ok {
			return u, true
		}
	}
	for _, u := range h.users {
		if strings.ToLower(u.CampusHandle) == clean || strings.ToLower(u.Email) == clean || strings.ToLower(u.ID) == clean {
			return u, true
		}
	}
	return model.User{}, false
}

// UpdateUserPassword updates a user's password, sets must_change_password to false, and persists to DB
func (h *UserHandler) UpdateUserPassword(identifier, newPassword string) (model.User, error) {
	h.mu.Lock()
	defer h.mu.Unlock()

	clean := strings.TrimSpace(strings.ToLower(identifier))
	var targetID string

	if u, ok := h.users[clean]; ok {
		targetID = u.ID
	} else if id, ok := h.handleToID[clean]; ok {
		targetID = id
	} else {
		for _, u := range h.users {
			if strings.ToLower(u.CampusHandle) == clean || strings.ToLower(u.Email) == clean || strings.ToLower(u.ID) == clean {
				targetID = u.ID
				break
			}
		}
	}

	if targetID == "" {
		return model.User{}, fmt.Errorf("user not found")
	}

	u := h.users[targetID]
	u.PasswordHash = HashPassword(newPassword)
	u.MustChangePassword = false
	u.UpdatedAt = time.Now().UTC()
	h.users[targetID] = u

	if h.db != nil {
		go func(uid, hash string, updated time.Time) {
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			_, _ = h.db.Exec(ctx, `UPDATE users SET password_hash = $1, must_change_password = false, updated_at = $2 WHERE id = $3`, hash, updated, uid)
		}(targetID, u.PasswordHash, u.UpdatedAt)
	}

	return u, nil
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

// GetStudentProfile resolves a student profile by user ID or campus handle
func (h *UserHandler) GetStudentProfile(identifier string) (*model.StudentProfile, bool) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	if sp, ok := h.studentProfiles[identifier]; ok {
		cp := sp
		return &cp, true
	}
	if id, ok := h.handleToID[identifier]; ok {
		if sp, ok := h.studentProfiles[id]; ok {
			cp := sp
			return &cp, true
		}
	}
	return nil, false
}

// UpdateStudentProfile updates or inserts a student's academic profile
func (h *UserHandler) UpdateStudentProfile(sp model.StudentProfile) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.studentProfiles[sp.UserID] = sp
	if u, exists := h.users[sp.UserID]; exists && sp.AcademicName != "" {
		u.AcademicName = sp.AcademicName
		h.users[sp.UserID] = u
	}
}

