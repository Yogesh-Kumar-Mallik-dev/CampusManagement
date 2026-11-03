package service

import (
	"context"
	"fmt"
	"sort"
	"sync"
	"time"

	"campus/backend/internal/cache"
	"campus/backend/internal/model"
	"github.com/jackc/pgx/v5/pgxpool"
)

type AcademicService struct {
	db          *pgxpool.Pool
	cache       *cache.ResilientManager
	permService *PermissionService
	mu          sync.RWMutex

	// In-memory repositories for offline/test mode and cache fallback
	courses        map[string]model.Course
	timetableSlots map[string]model.TimetableSlot
	sessions       map[string]model.AttendanceSession
	records        map[string]model.AttendanceRecord
	notices        map[string]model.Notice
}

func NewAcademicService(db *pgxpool.Pool, cache *cache.ResilientManager, permService *PermissionService) *AcademicService {
	return &AcademicService{
		db:             db,
		cache:          cache,
		permService:    permService,
		courses:        make(map[string]model.Course),
		timetableSlots: make(map[string]model.TimetableSlot),
		sessions:       make(map[string]model.AttendanceSession),
		records:        make(map[string]model.AttendanceRecord),
		notices:        make(map[string]model.Notice),
	}
}

// ----------------------------------------------------
// COURSES
// ----------------------------------------------------

func (s *AcademicService) CreateCourse(ctx context.Context, course model.Course) (model.Course, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now().UTC()
	if course.ID == "" {
		course.ID = fmt.Sprintf("course-%s", course.Code)
	}
	course.CreatedAt = now
	course.UpdatedAt = now
	course.IsDeleted = false

	s.courses[course.ID] = course
	return course, nil
}

func (s *AcademicService) ListCourses(ctx context.Context) ([]model.Course, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []model.Course
	for _, c := range s.courses {
		if !c.IsDeleted {
			result = append(result, c)
		}
	}
	sort.Slice(result, func(i, j int) bool { return result[i].Code < result[j].Code })
	return result, nil
}

// ----------------------------------------------------
// TIMETABLE
// ----------------------------------------------------

func (s *AcademicService) CreateTimetableSlot(ctx context.Context, slot model.TimetableSlot) (model.TimetableSlot, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now().UTC()
	if slot.ID == "" {
		slot.ID = fmt.Sprintf("slot-%d", time.Now().UnixNano())
	}
	slot.CreatedAt = now
	slot.UpdatedAt = now
	slot.IsDeleted = false

	// Enrich course details if present
	if c, ok := s.courses[slot.CourseID]; ok {
		slot.CourseCode = c.Code
		slot.CourseName = c.Name
	}

	s.timetableSlots[slot.ID] = slot
	return slot, nil
}

func (s *AcademicService) GetTimetableForScope(ctx context.Context, scopeCode string) ([]model.TimetableSlot, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []model.TimetableSlot
	for _, slot := range s.timetableSlots {
		if !slot.IsDeleted && (slot.ScopeCode == scopeCode || scopeCode == "" || scopeCode == "global") {
			result = append(result, slot)
		}
	}
	sort.Slice(result, func(i, j int) bool {
		if result[i].DayOfWeek == result[j].DayOfWeek {
			return result[i].StartTime < result[j].StartTime
		}
		return result[i].DayOfWeek < result[j].DayOfWeek
	})
	return result, nil
}

// ----------------------------------------------------
// OFFLINE-FIRST ATTENDANCE
// ----------------------------------------------------

func (s *AcademicService) SyncAttendanceBatch(ctx context.Context, markedByUserID string, batch model.OfflineAttendanceBatch) ([]model.AttendanceSession, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now().UTC()
	var savedSessions []model.AttendanceSession

	for _, session := range batch.Sessions {
		if session.ID == "" {
			session.ID = fmt.Sprintf("sess-%d", time.Now().UnixNano())
		}
		session.MarkedByUserID = markedByUserID
		session.CreatedAt = now
		session.UpdatedAt = now
		session.IsDeleted = false

		if c, ok := s.courses[session.CourseID]; ok {
			session.CourseCode = c.Code
			session.CourseName = c.Name
		}

		s.sessions[session.ID] = session

		// Upsert records
		for _, rec := range session.Records {
			if rec.ID == "" {
				rec.ID = fmt.Sprintf("rec-%s-%s", session.ID, rec.StudentID)
			}
			rec.SessionID = session.ID
			rec.CreatedAt = now
			rec.UpdatedAt = now
			rec.IsDeleted = false

			s.records[rec.ID] = rec
		}

		savedSessions = append(savedSessions, session)
	}

	return savedSessions, nil
}

func (s *AcademicService) GetStudentAttendanceSummary(ctx context.Context, studentID string) ([]model.AttendanceSummary, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	// Aggregated by Course
	type stats struct {
		total    int
		attended int
	}
	summaryMap := make(map[string]*stats)

	for _, rec := range s.records {
		if rec.IsDeleted || rec.StudentID != studentID {
			continue
		}
		sess, ok := s.sessions[rec.SessionID]
		if !ok || sess.IsDeleted {
			continue
		}

		if _, exists := summaryMap[sess.CourseID]; !exists {
			summaryMap[sess.CourseID] = &stats{}
		}

		summaryMap[sess.CourseID].total++
		if rec.Status == model.StatusPresent || rec.Status == model.StatusLate {
			summaryMap[sess.CourseID].attended++
		}
	}

	var results []model.AttendanceSummary
	for courseID, st := range summaryMap {
		var code, name string
		if c, ok := s.courses[courseID]; ok {
			code = c.Code
			name = c.Name
		} else {
			code = courseID
			name = "Course " + courseID
		}

		pct := 0.0
		if st.total > 0 {
			pct = (float64(st.attended) / float64(st.total)) * 100.0
		}

		results = append(results, model.AttendanceSummary{
			CourseID:      courseID,
			CourseCode:    code,
			CourseName:    name,
			TotalSessions: st.total,
			Attended:      st.attended,
			Percentage:    pct,
		})
	}

	sort.Slice(results, func(i, j int) bool { return results[i].CourseCode < results[j].CourseCode })
	return results, nil
}

// ----------------------------------------------------
// TARGETED NOTICES
// ----------------------------------------------------

func (s *AcademicService) PublishNotice(ctx context.Context, notice model.Notice) (model.Notice, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now().UTC()
	if notice.ID == "" {
		notice.ID = fmt.Sprintf("notice-%d", time.Now().UnixNano())
	}
	notice.CreatedAt = now
	notice.UpdatedAt = now
	notice.PublishedAt = now
	notice.IsDeleted = false
	if notice.Priority == "" {
		notice.Priority = "normal"
	}

	s.notices[notice.ID] = notice
	return notice, nil
}

func (s *AcademicService) GetTargetedNotices(ctx context.Context, userScopes []string) ([]model.Notice, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	scopeMap := make(map[string]bool)
	scopeMap["global"] = true
	scopeMap[""] = true
	for _, sc := range userScopes {
		scopeMap[sc] = true
	}

	var results []model.Notice
	for _, n := range s.notices {
		if n.IsDeleted {
			continue
		}
		// Notice matches if it's campus-wide or targeted to one of user's scopes
		if scopeMap[n.TargetScopeCode] {
			results = append(results, n)
		}
	}

	sort.Slice(results, func(i, j int) bool {
		return results[i].PublishedAt.After(results[j].PublishedAt)
	})
	return results, nil
}

// ----------------------------------------------------
// FULL DELTA SYNC (OFFLINE REPLICATION ENGINE)
// ----------------------------------------------------

func (s *AcademicService) GetDeltaSync(ctx context.Context, since time.Time, userScopes []string) (model.DeltaSyncResponse, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	resp := model.DeltaSyncResponse{
		ServerTime:         time.Now().UTC(),
		Courses:            make([]model.Course, 0),
		TimetableSlots:     make([]model.TimetableSlot, 0),
		AttendanceSessions: make([]model.AttendanceSession, 0),
		AttendanceRecords:  make([]model.AttendanceRecord, 0),
		Notices:            make([]model.Notice, 0),
	}

	scopeMap := make(map[string]bool)
	scopeMap["global"] = true
	scopeMap[""] = true
	for _, sc := range userScopes {
		scopeMap[sc] = true
	}

	for _, c := range s.courses {
		if c.UpdatedAt.After(since) {
			resp.Courses = append(resp.Courses, c)
		}
	}

	for _, slot := range s.timetableSlots {
		if slot.UpdatedAt.After(since) && (len(userScopes) == 0 || scopeMap[slot.ScopeCode]) {
			resp.TimetableSlots = append(resp.TimetableSlots, slot)
		}
	}

	for _, sess := range s.sessions {
		if sess.UpdatedAt.After(since) && (len(userScopes) == 0 || scopeMap[sess.ScopeCode]) {
			resp.AttendanceSessions = append(resp.AttendanceSessions, sess)
		}
	}

	for _, rec := range s.records {
		if rec.UpdatedAt.After(since) {
			resp.AttendanceRecords = append(resp.AttendanceRecords, rec)
		}
	}

	for _, n := range s.notices {
		if n.UpdatedAt.After(since) && scopeMap[n.TargetScopeCode] {
			resp.Notices = append(resp.Notices, n)
		}
	}

	return resp, nil
}
