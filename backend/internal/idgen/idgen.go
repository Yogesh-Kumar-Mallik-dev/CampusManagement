package idgen

import (
	"context"
	"fmt"
	"regexp"
	"strings"
	"sync"

	"github.com/jackc/pgx/v5/pgxpool"
)

var nonAlphaNumRegex = regexp.MustCompile(`[^a-z0-9]`)

// Sanitize normalizes names to lower-case alphanumeric strings
func Sanitize(str string) string {
	lower := strings.ToLower(strings.TrimSpace(str))
	return nonAlphaNumRegex.ReplaceAllString(lower, "")
}

// IDServiceInterface abstracts canonical handle identifier generation
type IDServiceInterface interface {
	NextStudentID(ctx context.Context, firstName string, admissionYear int, entryType, program string) (string, error)
	NextEmployeeID(ctx context.Context, firstName string, joiningYear int) (string, error)
	NextExternalID(ctx context.Context, firstName string, onboardingYear int) (string, error)
	NextFacultyID(ctx context.Context, firstName string, joiningYear int) (string, error)
	NextStaffID(ctx context.Context, firstName string, joiningYear int) (string, error)
}

type IDService struct {
	db        *pgxpool.Pool
	mu        sync.Mutex
	memCounts map[string]int // fallback for tests or offline dev
}

func NewIDService(db *pgxpool.Pool) *IDService {
	return &IDService{
		db:        db,
		memCounts: make(map[string]int),
	}
}

// NextStudentID: {name}_{admissionYear}_{entryType}_{program}_{seq}
// e.g. "Harish", 2025, "lateral", "btech" -> "harish_2025_l_btech_3"
func (s *IDService) NextStudentID(ctx context.Context, firstName string, admissionYear int, entryType, program string) (string, error) {
	name := Sanitize(firstName)
	if name == "" {
		name = "student"
	}
	entryCode := "r"
	cleanEntry := strings.ToLower(strings.TrimSpace(entryType))
	if strings.HasPrefix(cleanEntry, "l") {
		entryCode = "l" // lateral
	} else if strings.HasPrefix(cleanEntry, "t") {
		entryCode = "t" // transfer
	}

	cleanProg := Sanitize(program)
	if cleanProg == "" {
		cleanProg = "gen"
	}

	prefix := fmt.Sprintf("%s_%d_%s_%s", name, admissionYear, entryCode, cleanProg)
	return s.atomicIncrement(ctx, prefix)
}

// NextEmployeeID: {name}_{joiningYear}_emp_{seq}
// e.g. "Priya", 2024 -> "priya_2024_emp_1"
// Fully immutable across:
// 1. Academic promotions (Asst Prof -> Associate Prof -> Professor -> Dean)
// 2. Department transfers or joint appointments
// 3. Transitions between Faculty and Administrative/Staff roles
// 4. Employees holding both academic and operational positions simultaneously
func (s *IDService) NextEmployeeID(ctx context.Context, firstName string, joiningYear int) (string, error) {
	name := Sanitize(firstName)
	if name == "" {
		name = "employee"
	}
	prefix := fmt.Sprintf("%s_%d_emp", name, joiningYear)
	return s.atomicIncrement(ctx, prefix)
}

// NextExternalID: {name}_{onboardingYear}_ext_{seq}
// e.g. "Mukesh", 2025 -> "mukesh_2025_ext_1"
// For contractors, outsourced staff, canteen vendors, mess operators.
func (s *IDService) NextExternalID(ctx context.Context, firstName string, onboardingYear int) (string, error) {
	name := Sanitize(firstName)
	if name == "" {
		name = "external"
	}
	prefix := fmt.Sprintf("%s_%d_ext", name, onboardingYear)
	return s.atomicIncrement(ctx, prefix)
}

// NextFacultyID is an alias for NextEmployeeID to guarantee identity stability
func (s *IDService) NextFacultyID(ctx context.Context, firstName string, joiningYear int) (string, error) {
	return s.NextEmployeeID(ctx, firstName, joiningYear)
}

// NextStaffID is an alias for NextEmployeeID to guarantee identity stability
func (s *IDService) NextStaffID(ctx context.Context, firstName string, joiningYear int) (string, error) {
	return s.NextEmployeeID(ctx, firstName, joiningYear)
}

func (s *IDService) atomicIncrement(ctx context.Context, prefix string) (string, error) {
	if s.db != nil {
		var handle string
		query := "SELECT generate_campus_handle($1)"
		err := s.db.QueryRow(ctx, query, prefix).Scan(&handle)
		if err == nil && handle != "" {
			return handle, nil
		}
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	s.memCounts[prefix]++
	return fmt.Sprintf("%s_%d", prefix, s.memCounts[prefix]), nil
}
