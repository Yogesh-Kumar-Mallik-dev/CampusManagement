package model

import "time"

type Archetype string

const (
	ArchetypeStudent  Archetype = "student"
	ArchetypeEmployee Archetype = "employee" // Unified for both Faculty and Staff
	ArchetypeExternal Archetype = "external" // Contractors, vendors, visitors
)

// User represents the core identity
type User struct {
	BaseSyncModel
	CampusHandle           string     `json:"campus_handle"` // e.g. harish_2025_l_btech_1, priya_2024_emp_1
	FirstName              string     `json:"first_name"`
	LastName               string     `json:"last_name"`
	Email                  string     `json:"email"`
	PersonalEmail          string     `json:"personal_email,omitempty"`
	Phone                  string     `json:"phone,omitempty"`
	EmergencyContactName   string     `json:"emergency_contact_name,omitempty"`
	EmergencyContactPhone  string     `json:"emergency_contact_phone,omitempty"`
	BloodGroup             string     `json:"blood_group,omitempty"`
	Address                string     `json:"address,omitempty"`
	Archetype              Archetype  `json:"archetype"`
	AdmissionApplicationNo string     `json:"admission_application_no,omitempty"`
	UniversityRollNo       string     `json:"university_roll_no,omitempty"`
	UniversityRegNo        string     `json:"university_reg_no,omitempty"`
	IsActive               bool       `json:"is_active"`
	Status                 string     `json:"status"` // 'active', 'graduated', 'discontinued', 'suspended', 'resigned', 'retired'
	DiscontinuationReason  string     `json:"discontinuation_reason,omitempty"`
	DiscontinuedAt         *time.Time `json:"discontinued_at,omitempty"`
	DiscontinuedBy         string     `json:"discontinued_by,omitempty"`
}

func (u User) FullName() string {
	if u.FirstName == "" {
		return u.LastName
	}
	if u.LastName == "" {
		return u.FirstName
	}
	return u.FirstName + " " + u.LastName
}

// UserProfileResponse aggregates complete institutional identity facts
type UserProfileResponse struct {
	User                  User                   `json:"user"`
	StudentProfile        *StudentProfile        `json:"student_profile,omitempty"`
	EmployeeRecord        *EmployeeRecord        `json:"employee_record,omitempty"`
	AcademicProfile       *AcademicProfile       `json:"academic_profile,omitempty"`
	AdministrativeProfile *AdministrativeProfile `json:"administrative_profile,omitempty"`
	ContractorProfile     *ContractorProfile     `json:"contractor_profile,omitempty"`
	AssignedRoles         []UserRoleAssignment   `json:"assigned_roles,omitempty"`
}

// UpdateUserProfileRequest holds self-service editable contact fields
type UpdateUserProfileRequest struct {
	UserID                string `json:"user_id"`
	PersonalEmail         string `json:"personal_email,omitempty"`
	Phone                 string `json:"phone,omitempty"`
	EmergencyContactName  string `json:"emergency_contact_name,omitempty"`
	EmergencyContactPhone string `json:"emergency_contact_phone,omitempty"`
	BloodGroup            string `json:"blood_group,omitempty"`
	Address               string `json:"address,omitempty"`
}

// StudentProfile holds academic admission facts
type StudentProfile struct {
	UserID                string  `json:"user_id"`
	AdmissionYear         int     `json:"admission_year"`
	EntryType             string  `json:"entry_type"` // 'regular', 'lateral', 'transfer'
	Program               string  `json:"program"`    // 'btech', 'mtech', 'phd'
	ProgramID             *string `json:"program_id,omitempty"` // Degree program e.g. 'prog-btech-cse'
	ProgramCode           string  `json:"program_code,omitempty"`
	ProgramName           string  `json:"program_name,omitempty"`
	CurrentSemester       int     `json:"current_semester"`
	BatchYear             int     `json:"batch_year"`
	SectionScope          string  `json:"section_scope,omitempty"` // e.g. 'sec:cse-3a'
	SectionID             *string `json:"section_id,omitempty"`    // Cross-program section cohort e.g. 'sec-sem3-b'
	SectionName           string  `json:"section_name,omitempty"`
	SemesterID            *string `json:"semester_id,omitempty"`
	AdvisorName           string  `json:"advisor_name,omitempty"`
	HostelBlock           string  `json:"hostel_block,omitempty"`
	RoomNumber            string  `json:"room_number,omitempty"`
	EmergencyContactName  string  `json:"emergency_contact_name,omitempty"`
	EmergencyContactPhone string  `json:"emergency_contact_phone,omitempty"`
}

// EmployeeRecord holds HR and institutional employment anchor
type EmployeeRecord struct {
	UserID                string    `json:"user_id"`
	JoiningDate           time.Time `json:"joining_date"`
	EmployeeCode          string    `json:"employee_code,omitempty"`
	EmploymentType        string    `json:"employment_type"` // 'permanent', 'contract', 'visiting'
	IsAcademic            bool      `json:"is_academic"`       // Has teaching/research duties
	IsAdministrative      bool      `json:"is_administrative"` // Has operations/admin duties
	EmergencyContactName  string    `json:"emergency_contact_name,omitempty"`
	EmergencyContactPhone string    `json:"emergency_contact_phone,omitempty"`
}

// AcademicProfile holds academic appointment facts (teaching, research)
type AcademicProfile struct {
	UserID          string   `json:"user_id"`
	AcademicRank    string   `json:"academic_rank"` // 'Assistant Professor', 'Professor'
	CabinLocation   string   `json:"cabin_location,omitempty"`
	GoogleScholarID string   `json:"google_scholar_id,omitempty"`
	ResearchAreas   []string `json:"research_areas,omitempty"`
	Departments     []string `json:"department_affiliations,omitempty"`
}

// AdministrativeProfile holds administrative/operational management facts
type AdministrativeProfile struct {
	UserID         string `json:"user_id"`
	PrimaryUnit    string `json:"primary_unit"`    // 'registrar', 'security', 'library', 'it_center'
	Designation    string `json:"designation"`     // 'Registrar', 'Chief Security Officer', 'Lab Incharge'
	OfficeLocation string `json:"office_location,omitempty"`
}

// ContractorProfile holds vendor service information
type ContractorProfile struct {
	UserID             string     `json:"user_id"`
	OnboardingYear     int        `json:"onboarding_year"`
	VendorOrganization string     `json:"vendor_organization"`
	ServiceType        string     `json:"service_type"` // 'canteen', 'mess', 'cleaning', 'security', 'transport', 'maintenance'
	ContractExpiresAt  *time.Time `json:"contract_expires_at,omitempty"`
	GatePassID         string     `json:"gate_pass_id,omitempty"`
	SupervisorName     string     `json:"supervisor_name,omitempty"`
	SupervisorPhone    string     `json:"supervisor_phone,omitempty"`
	PermittedScopes    []string   `json:"permitted_scopes,omitempty"`
}
