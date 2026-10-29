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
	CampusHandle           string    `json:"campus_handle"` // e.g. harish_2025_l_btech_1, priya_2024_emp_1
	FirstName              string    `json:"first_name"`
	LastName               string    `json:"last_name"`
	Email                  string    `json:"email"`
	PersonalEmail          string    `json:"personal_email,omitempty"`
	Phone                  string    `json:"phone,omitempty"`
	Archetype              Archetype `json:"archetype"`
	AdmissionApplicationNo string    `json:"admission_application_no,omitempty"`
	UniversityRollNo       string    `json:"university_roll_no,omitempty"`
	UniversityRegNo        string    `json:"university_reg_no,omitempty"`
	IsActive               bool      `json:"is_active"`
}

// StudentProfile holds academic admission facts
type StudentProfile struct {
	UserID          string `json:"user_id"`
	AdmissionYear   int    `json:"admission_year"`
	EntryType       string `json:"entry_type"` // 'regular', 'lateral', 'transfer'
	Program         string `json:"program"`    // 'btech', 'mtech', 'phd'
	CurrentSemester int    `json:"current_semester"`
	BatchYear       int    `json:"batch_year"`
}

// EmployeeRecord holds HR and institutional employment anchor
type EmployeeRecord struct {
	UserID           string    `json:"user_id"`
	JoiningDate      time.Time `json:"joining_date"`
	EmployeeCode     string    `json:"employee_code,omitempty"`
	EmploymentType   string    `json:"employment_type"` // 'permanent', 'contract', 'visiting'
	IsAcademic       bool      `json:"is_academic"`       // Has teaching/research duties
	IsAdministrative bool      `json:"is_administrative"` // Has operations/admin duties
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
	ServiceType        string     `json:"service_type"` // 'canteen', 'mess', 'cleaning'
	ContractExpiresAt  *time.Time `json:"contract_expires_at,omitempty"`
}
