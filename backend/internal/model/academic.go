package model

// Department represents an academic department (e.g. Computer Science, Electronics, Mathematics)
type Department struct {
	BaseSyncModel
	Code        string   `json:"code"`        // Unique code e.g. 'CSE', 'ECE', 'MATH'
	Name        string   `json:"name"`        // e.g. 'Computer Science & Engineering'
	Description string   `json:"description"` // Department overview/mission
	HODID       *string  `json:"hod_id,omitempty"`
	HODName     string   `json:"hod_name,omitempty"`

	// Many-to-Many relationship IDs
	SubjectIDs  []string `json:"subject_ids,omitempty"`  // Many-to-many subjects
	TeacherIDs  []string `json:"teacher_ids,omitempty"`  // Many-to-many teachers
	SemesterIDs []string `json:"semester_ids,omitempty"` // Many-to-many program semesters

	// Aggregated metrics for directory listing
	SubjectCount  int `json:"subject_count"`
	TeacherCount  int `json:"teacher_count"`
	SemesterCount int `json:"semester_count"`
}

// Program represents an overarching degree course (e.g. B.Tech Computer Science, MBA)
type Program struct {
	BaseSyncModel
	Code           string `json:"code"`            // e.g. 'BTECH-CSE'
	Name           string `json:"name"`            // e.g. 'Bachelor of Technology in Computer Science'
	DegreeLevel    string `json:"degree_level"`    // 'undergraduate', 'postgraduate', 'doctoral'
	TotalSemesters int    `json:"total_semesters"` // e.g. 8
}

// Subject represents an academic subject/course module
type Subject struct {
	BaseSyncModel
	Code           string           `json:"code"`                    // Canonical display e.g. 'BCA 102/202' or 'CS301'
	OddSemCode     string           `json:"odd_sem_code,omitempty"`  // e.g. 'BCA-102' for odd semesters (Sem 1, 3, 5...)
	EvenSemCode    string           `json:"even_sem_code,omitempty"` // e.g. 'BCA-202' for even semesters (Sem 2, 4, 6...)
	Name           string           `json:"name"`                    // e.g. 'Computer Fundamentals & Programming'
	Credits        int              `json:"credits"`                 // e.g. 4
	DepartmentIDs  []string         `json:"department_ids,omitempty"`// Departments offering this subject
	ActiveSyllabus *SyllabusVersion `json:"active_syllabus,omitempty"`// Currently active curriculum
}

// ResolveCodeForSemester returns the term-specific code if odd/even codes are configured
func (s Subject) ResolveCodeForSemester(semNumber int) string {
	if semNumber%2 == 1 && s.OddSemCode != "" {
		return s.OddSemCode
	}
	if semNumber%2 == 0 && s.EvenSemCode != "" {
		return s.EvenSemCode
	}
	return s.Code
}

// SyllabusVersion stores an immutable version of a course syllabus for academic audits
type SyllabusVersion struct {
	BaseSyncModel
	SubjectID         string  `json:"subject_id"`
	RevisionCode      string  `json:"revision_code"`       // e.g. 'Reg-2024', 'v1.0'
	EffectiveFromYear string  `json:"effective_from_year"` // '2024-2025'
	EffectiveToYear   *string `json:"effective_to_year,omitempty"`
	IsActive          bool    `json:"is_active"`
	Content           string  `json:"content"`             // Modular text / units / references
	ChangeSummary     string  `json:"change_summary,omitempty"`
	ApprovedBy        string  `json:"approved_by,omitempty"`
	ApprovedAt        *string `json:"approved_at,omitempty"`
}

// ReviseSyllabusRequest is the payload to publish a new syllabus scheme, archiving the previous one
type ReviseSyllabusRequest struct {
	SubjectID         string `json:"subject_id"`
	RevisionCode      string `json:"revision_code"`
	EffectiveFromYear string `json:"effective_from_year"`
	Content           string `json:"content"`
	ChangeSummary     string `json:"change_summary"`
	ApprovedBy        string `json:"approved_by"`
}

// Semester represents a specific semester cohort from a program (e.g. B.Tech CSE Semester 5, Sec 3A)
type Semester struct {
	BaseSyncModel
	ProgramID      string   `json:"program_id"`
	ProgramCode    string   `json:"program_code"`
	ProgramName    string   `json:"program_name"`
	SemesterNumber int      `json:"semester_number"` // 1 through TotalSemesters
	AcademicYear   string   `json:"academic_year"`   // e.g. '2025-2026'
	Section        string   `json:"section"`         // e.g. '3A'
	DisplayName    string   `json:"display_name"`    // e.g. 'B.Tech CSE - Semester 5 (Sec 3A)'

	// Many-to-Many relationships within the Department
	SubjectIDs     []string `json:"subject_ids,omitempty"` // Subjects offered in this semester
	TeacherIDs     []string `json:"teacher_ids,omitempty"` // Faculty teaching this semester

	// Students have a Many-to-One relationship with Semester (not directly to Department)
	StudentCount   int      `json:"student_count"`
}

// DepartmentDetail provides full hydrated details for inspector view
type DepartmentDetail struct {
	Department Department `json:"department"`
	Subjects   []Subject  `json:"subjects"`
	Teachers   []User     `json:"teachers"`
	Semesters  []Semester `json:"semesters"`
}

// SemesterDetail provides full hydrated semester details including enrolled students
type SemesterDetail struct {
	Semester Semester  `json:"semester"`
	Subjects []Subject `json:"subjects"`
	Teachers []User    `json:"teachers"`
	Students []User    `json:"students"` // Many-to-one enrolled students
}

// CreateDepartmentRequest is the client payload to add a new department
type CreateDepartmentRequest struct {
	Code        string   `json:"code"`
	Name        string   `json:"name"`
	Description string   `json:"description"`
	HODID       *string  `json:"hod_id,omitempty"`
	SubjectIDs  []string `json:"subject_ids,omitempty"`
	TeacherIDs  []string `json:"teacher_ids,omitempty"`
	SemesterIDs []string `json:"semester_ids,omitempty"`
}

// Section represents a classroom cohort/division in a semester that can be shared across multiple programs
// (e.g. Section B in Years 1-2 shared across B.Tech CSE, AI/ML, and DS cohorts).
type Section struct {
	BaseSyncModel
	Name           string   `json:"name"`            // e.g. 'Section B'
	SemesterNumber int      `json:"semester_number"` // 1 through 8
	AcademicYear   string   `json:"academic_year"`   // e.g. '2025-2026'
	DisplayName    string   `json:"display_name"`    // e.g. 'Semester 3 - Section B'
	DepartmentID   *string  `json:"department_id,omitempty"`

	// Many-to-Many Programs sharing this section cohort
	ProgramIDs   []string `json:"program_ids,omitempty"`   // e.g. ['prog-btech-cse', 'prog-btech-aiml', 'prog-btech-ds']
	ProgramNames []string `json:"program_names,omitempty"` // e.g. ['B.Tech CSE', 'B.Tech AI/ML']

	// Many-to-Many Subjects & Teachers
	SubjectIDs []string `json:"subject_ids,omitempty"`
	TeacherIDs []string `json:"teacher_ids,omitempty"`

	// Student enrollment metrics
	StudentCount int `json:"student_count"`
}

// SectionSubjectAllocation details whether a subject in the section is shared across all programs
// or specific to one program (e.g. AI/ML elective in Semester 5).
type SectionSubjectAllocation struct {
	SubjectID   string  `json:"subject_id"`
	SubjectCode string  `json:"subject_code"`
	SubjectName string  `json:"subject_name"`
	Credits     int     `json:"credits"`
	ProgramID   *string `json:"program_id,omitempty"`   // nil = shared common subject; non-nil = program-specific
	ProgramCode *string `json:"program_code,omitempty"` // e.g. 'BTECH-AIML'
	ProgramName *string `json:"program_name,omitempty"`
	TeacherID   *string `json:"teacher_id,omitempty"`
	TeacherName *string `json:"teacher_name,omitempty"`
}

// SectionDetail provides full hydrated details for a section cohort
type SectionDetail struct {
	Section            Section                    `json:"section"`
	Programs           []Program                  `json:"programs"`
	Subjects           []Subject                  `json:"subjects"`
	SubjectAllocations []SectionSubjectAllocation `json:"subject_allocations"`
	Teachers           []User                     `json:"teachers"`
	Students           []User                     `json:"students"`
	ProgramBreakdown   map[string]int             `json:"program_breakdown,omitempty"` // programCode -> student count
}

// CreateSectionRequest is the payload to create a new section cohort
type CreateSectionRequest struct {
	Name           string   `json:"name"`            // e.g. 'Section B'
	SemesterNumber int      `json:"semester_number"` // e.g. 3
	AcademicYear   string   `json:"academic_year"`   // e.g. '2025-2026'
	DepartmentID   *string  `json:"department_id,omitempty"`
	ProgramIDs     []string `json:"program_ids"`     // M:N Programs
	SubjectIDs     []string `json:"subject_ids,omitempty"`
	TeacherIDs     []string `json:"teacher_ids,omitempty"`
}

