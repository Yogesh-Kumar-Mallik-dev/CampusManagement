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
	Gender                 string     `json:"gender,omitempty"` // 'male', 'female', 'other', 'prefer_not_to_say'
	AcademicName           string     `json:"academic_name,omitempty"` // Official name as verified on 10th/Matriculation record
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
	MustChangePassword     bool       `json:"must_change_password"`
	IsFirstLogin           bool       `json:"is_first_login"`
	SecurityQuestion       string     `json:"security_question,omitempty"`
	SecurityAnswerHash     string     `json:"-"`
	WhatsAppPhone          string     `json:"whatsapp_phone,omitempty"`
	PasswordHash           string     `json:"-"`
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
	Permissions           []string               `json:"permissions,omitempty"`
}

// UpdateUserProfileRequest holds self-service editable contact fields
type UpdateUserProfileRequest struct {
	UserID                string `json:"user_id"`
	PersonalEmail         string `json:"personal_email,omitempty"`
	Phone                 string `json:"phone,omitempty"`
	Gender                string `json:"gender,omitempty"`
	AcademicName          string `json:"academic_name,omitempty"`
	AcademicNameSource    string `json:"academic_name_source,omitempty"`
	ClassXDocumentRef     string `json:"class_x_document_ref,omitempty"`
	EmergencyContactName  string `json:"emergency_contact_name,omitempty"`
	EmergencyContactPhone string `json:"emergency_contact_phone,omitempty"`
	BloodGroup            string `json:"blood_group,omitempty"`
	Address               string `json:"address,omitempty"`
}

// VerifiedDocument represents a government-verified digital credential from DigiLocker / NAD
type VerifiedDocument struct {
	DocumentType     string `json:"document_type"`     // 'class_x', 'class_xii', 'aadhaar_kyc', 'apaar_abc', 'domicile'
	DocumentTitle    string `json:"document_title"`    // e.g. 'Class X Secondary School Certificate'
	Issuer           string `json:"issuer"`            // e.g. 'Central Board of Secondary Education (CBSE)'
	DocRefMasked     string `json:"doc_ref_masked"`    // e.g. 'ROLL-21109841' or 'XXXX-XXXX-4091'
	IssuedYear       int    `json:"issued_year"`
	IsVerified       bool   `json:"is_verified"`
	VerificationHash string `json:"verification_hash"` // Cryptographic SHA256 digest
	VerifiedAt       string `json:"verified_at"`
	Status           string `json:"status"`            // 'verified', 'pending', 'revoked'
}

// StudentProfile holds academic admission facts
type StudentProfile struct {
	UserID                string             `json:"user_id"`
	AdmissionYear         int                `json:"admission_year"`
	EntryType             string             `json:"entry_type"` // 'regular', 'lateral', 'transfer'
	Program               string             `json:"program"`    // 'btech', 'mtech', 'phd'
	AcademicName          string             `json:"academic_name,omitempty"` // Official name as per 10th / equivalent certificate
	AcademicNameVerified  bool               `json:"academic_name_verified"`
	AcademicNameSource    string             `json:"academic_name_source,omitempty"` // 'digilocker_class_x', 'manual_pdf_upload', 'direct_entry'
	ClassXDocumentRef     string             `json:"class_x_document_ref,omitempty"`
	ProgramID             *string            `json:"program_id,omitempty"` // Degree program e.g. 'prog-btech-cse'
	ProgramCode           string             `json:"program_code,omitempty"`
	ProgramName           string             `json:"program_name,omitempty"`
	CurrentSemester       int                `json:"current_semester"`
	BatchYear             int                `json:"batch_year"`
	SectionScope          string             `json:"section_scope,omitempty"` // e.g. 'sec:cse-3a'
	SectionID             *string            `json:"section_id,omitempty"`    // Cross-program section cohort e.g. 'sec-sem3-b'
	SectionName           string             `json:"section_name,omitempty"`
	SemesterID            *string            `json:"semester_id,omitempty"`
	AdvisorName           string             `json:"advisor_name,omitempty"`
	HostelBlock           string             `json:"hostel_block,omitempty"`
	RoomNumber            string             `json:"room_number,omitempty"`
	EmergencyContactName  string             `json:"emergency_contact_name,omitempty"`
	EmergencyContactPhone string             `json:"emergency_contact_phone,omitempty"`
	ABCID                 string             `json:"abc_id,omitempty"` // 12-digit APAAR / ABC ID
	DigiLockerVerified    bool               `json:"digilocker_verified"`
	DigiLockerVerifiedAt  *time.Time         `json:"digilocker_verified_at,omitempty"`
	VerifiedDocuments     []VerifiedDocument `json:"verified_documents,omitempty"`
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

// RequestOTPRequest triggers WhatsApp OTP delivery
type RequestOTPRequest struct {
	Identifier string `json:"identifier"` // Campus handle, email, or phone
	Purpose    string `json:"purpose"`    // "first_login" or "password_reset"
}

// RequestOTPResponse returns delivery status
type RequestOTPResponse struct {
	Status        string `json:"status"`
	Message       string `json:"message"`
	TargetPhone   string `json:"target_phone_masked"`
	ExpiresInSecs int    `json:"expires_in_seconds"`
	ResendCooldownSecs int `json:"resend_cooldown_seconds"`
}

// FirstLoginSetPasswordRequest verifies OTP, sets permanent password and configures security question
type FirstLoginSetPasswordRequest struct {
	Identifier       string `json:"identifier"`
	OTPCode          string `json:"otp_code"`
	NewPassword      string `json:"new_password"`
	SecurityQuestion string `json:"security_question"`
	SecurityAnswer   string `json:"security_answer"`
}

// ResetPasswordWithQuestionRequest uses WhatsApp OTP + Security Question to set new password
type ResetPasswordWithQuestionRequest struct {
	Identifier     string `json:"identifier"`
	OTPCode        string `json:"otp_code"`
	SecurityAnswer string `json:"security_answer"`
	NewPassword    string `json:"new_password"`
}

// ResetEscalationTicket models a pending or resolved IT helpdesk escalation
type ResetEscalationTicket struct {
	BaseSyncModel
	TicketNumber      string     `json:"ticket_number"`
	UserID            string     `json:"user_id"`
	CampusHandle      string     `json:"campus_handle"`
	FullName          string     `json:"full_name"`
	WhatsAppPhone     string     `json:"whatsapp_phone"`
	Status            string     `json:"status"` // "pending", "approved", "rejected", "resolved"
	EscalationReason  string     `json:"escalation_reason"`
	AdminTokenHash    string     `json:"-"`
	AdminTokenExpires *time.Time `json:"admin_token_expires,omitempty"`
	ResolvedBy        string     `json:"resolved_by,omitempty"`
	ResolvedAt        *time.Time `json:"resolved_at,omitempty"`
}

// CreateResetEscalationRequest creates an escalation ticket after WhatsApp OTP verification
type CreateResetEscalationRequest struct {
	Identifier string `json:"identifier"`
	OTPCode    string `json:"otp_code"`
	Reason     string `json:"reason,omitempty"`
}

// AdminResolveEscalationRequest allows campus admin to approve escalation and generate a token
type AdminResolveEscalationRequest struct {
	TicketNumber string `json:"ticket_number"`
	Action       string `json:"action"` // "approve" or "reject"
	AdminUserID  string `json:"admin_user_id"`
}

// AdminResolveEscalationResponse returns the generated admin token on approval
type AdminResolveEscalationResponse struct {
	Status       string `json:"status"`
	TicketNumber string `json:"ticket_number"`
	AdminToken   string `json:"admin_token,omitempty"`
	Message      string `json:"message"`
}

// ResetPasswordWithAdminTokenRequest completes password reset using WhatsApp OTP + Admin Token
type ResetPasswordWithAdminTokenRequest struct {
	Identifier  string `json:"identifier"`
	OTPCode     string `json:"otp_code"`
	AdminToken  string `json:"admin_token"`
	NewPassword string `json:"new_password"`
}

