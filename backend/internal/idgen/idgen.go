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

// NextFacultyID: {name}_{joiningYear}_fac_{seq}
// e.g. "Priya", 2024 -> "priya_2024_fac_1"
// Fully immutable across promotions (Asst Prof -> Prof -> Dean) and across department transfers.
func (s *IDService) NextFacultyID(ctx context.Context, firstName string, joiningYear int) (string, error) {
	name := Sanitize(firstName)
	if name == "" {
		name = "faculty"
	}
	prefix := fmt.Sprintf("%s_%d_fac", name, joiningYear)
	return s.atomicIncrement(ctx, prefix)
}

// NextStaffID: {name}_{joiningYear}_stf_{seq}
// e.g. "Ramesh", 2023 -> "ramesh_2023_stf_1"
// Fully immutable across promotions and transfers (security -> library -> exam cell).
func (s *IDService) NextStaffID(ctx context.Context, firstName string, joiningYear int) (string, error) {
	name := Sanitize(firstName)
	if name == "" {
		name = "staff"
	}
	prefix := fmt.Sprintf("%s_%d_stf", name, joiningYear)
	return s.atomicIncrement(ctx, prefix)
}

// NextContractorID: {name}_{onboardingYear}_ext_{seq}
// e.g. "Mukesh", 2025 -> "mukesh_2025_ext_1"
// Fully immutable across catering agency swaps or vendor renewals.
func (s *IDService) NextContractorID(ctx context.Context, firstName string, onboardingYear int) (string, error) {
	name := Sanitize(firstName)
	if name == "" {
		name = "external"
	}
	prefix := fmt.Sprintf("%s_%d_ext", name, onboardingYear)
	return s.atomicIncrement(ctx, prefix)
}

func (s *IDService) atomicIncrement(ctx context.Context, prefix string) (string, error) {
	// If PostgreSQL is available, use database sequence function
	if s.db != nil {
		var handle string
		query := "SELECT generate_campus_handle($1)"
		err := s.db.QueryRow(ctx, query, prefix).Scan(&handle)
		if err == nil && handle != "" {
			return handle, nil
		}
	}

	// In-memory fallback (for unit tests / initial bootstrap)
	s.mu.Lock()
	defer s.mu.Unlock()
	s.memCounts[prefix]++
	return fmt.Sprintf("%s_%d", prefix, s.memCounts[prefix]), nil
}
