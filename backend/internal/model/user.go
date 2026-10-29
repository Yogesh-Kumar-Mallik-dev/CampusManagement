package model

import "time"

type Archetype string

const (
	ArchetypeStudent    Archetype = "student"
	ArchetypeFaculty    Archetype = "faculty"
	ArchetypeStaff      Archetype = "staff"
	ArchetypeContractor Archetype = "contractor"
)

// User represents the core identity
type User struct {
	BaseSyncModel
	CampusHandle           string    `json:"campus_handle"`
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

// FacultyProfile holds mutable academic appointments
type FacultyProfile struct {
	UserID        string   `json:"user_id"`
	JoiningYear   int      `json:"joining_year"`
	Designation   string   `json:"designation"`
	CabinLocation string   `json:"cabin_location,omitempty"`
	Affiliations  []string `json:"department_affiliations,omitempty"`
}

// StaffProfile holds administrative/operational information
type StaffProfile struct {
	UserID      string `json:"user_id"`
	JoiningYear int    `json:"joining_year"`
	Unit        string `json:"unit"` // 'security', 'library', 'examination', 'hostel'
	Designation string `json:"designation"`
}

// ContractorProfile holds vendor service information
type ContractorProfile struct {
	UserID             string     `json:"user_id"`
	OnboardingYear     int        `json:"onboarding_year"`
	VendorOrganization string     `json:"vendor_organization"`
	ServiceType        string     `json:"service_type"` // 'canteen', 'mess', 'cleaning'
	ContractExpiresAt  *time.Time `json:"contract_expires_at,omitempty"`
}
