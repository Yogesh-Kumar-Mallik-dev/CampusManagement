package service

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"sort"
	"strings"
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

	// Optical Data Transfer Attendance state
	opticalSessions    map[string]*model.OpticalAttendanceSession
	verifiedBySession  map[string]map[string]bool // sessionID -> studentID -> true

	// Departments & Academic Hierarchy (M:N and N:1)
	departments   map[string]model.Department
	programs      map[string]model.Program
	semesters     map[string]model.Semester
	subjects      map[string]model.Subject
	deptSubjects  map[string]map[string]bool // deptID -> subjectID -> true
	deptTeachers  map[string]map[string]bool // deptID -> teacherID -> true
	deptSemesters map[string]map[string]bool // deptID -> semesterID -> true
	semSubjects   map[string]map[string]bool // semesterID -> subjectID -> true
	semTeachers   map[string]map[string]bool // semesterID -> teacherID -> true
	semStudents   map[string]map[string]bool // semesterID -> studentID -> true

	// Cross-program Sections (Shared cohorts e.g. Year 1-2 Section B across CSE, AI/ML, DS)
	sections        map[string]model.Section
	secPrograms     map[string]map[string]bool // sectionID -> programID -> true
	secSubjects     map[string][]model.SectionSubjectAllocation // sectionID -> subject allocations
	secTeachers     map[string]map[string]bool // sectionID -> teacherID -> true
	secStudents     map[string]map[string]bool // sectionID -> studentID -> true
	studentPrograms map[string]string          // studentID -> programID
}

func NewAcademicService(db *pgxpool.Pool, cache *cache.ResilientManager, permService *PermissionService) *AcademicService {
	return &AcademicService{
		db:                 db,
		cache:              cache,
		permService:        permService,
		courses:            make(map[string]model.Course),
		timetableSlots:     make(map[string]model.TimetableSlot),
		sessions:           make(map[string]model.AttendanceSession),
		records:            make(map[string]model.AttendanceRecord),
		notices:            make(map[string]model.Notice),
		opticalSessions:    make(map[string]*model.OpticalAttendanceSession),
		verifiedBySession:  make(map[string]map[string]bool),
		departments:        make(map[string]model.Department),
		programs:           make(map[string]model.Program),
		semesters:          make(map[string]model.Semester),
		subjects:           make(map[string]model.Subject),
		deptSubjects:       make(map[string]map[string]bool),
		deptTeachers:       make(map[string]map[string]bool),
		deptSemesters:      make(map[string]map[string]bool),
		semSubjects:        make(map[string]map[string]bool),
		semTeachers:        make(map[string]map[string]bool),
		semStudents:        make(map[string]map[string]bool),
		sections:           make(map[string]model.Section),
		secPrograms:        make(map[string]map[string]bool),
		secSubjects:        make(map[string][]model.SectionSubjectAllocation),
		secTeachers:        make(map[string]map[string]bool),
		secStudents:        make(map[string]map[string]bool),
		studentPrograms:    make(map[string]string),
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

// ----------------------------------------------------
// OPTICAL DATA TRANSFER ATTENDANCE (RAPIDLY CHANGING QR)
// ----------------------------------------------------

func (s *AcademicService) StartOpticalSession(ctx context.Context, session model.OpticalAttendanceSession) (*model.OpticalAttendanceSession, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now().UTC()
	if session.ID == "" {
		session.ID = fmt.Sprintf("opt-sess-%d", now.UnixNano())
	}

	if session.SessionSecret == "" {
		bytes := make([]byte, 16)
		if _, err := rand.Read(bytes); err == nil {
			session.SessionSecret = hex.EncodeToString(bytes)
		} else {
			session.SessionSecret = fmt.Sprintf("secret-%d", now.UnixNano())
		}
	}

	if session.RefreshInterval <= 0 {
		session.RefreshInterval = 1500 // 1.5 seconds default
	}

	session.StartedAt = now
	session.ExpiresAt = now.Add(90 * time.Minute)
	session.IsActive = true
	session.VerifiedRecords = []model.AttendanceRecord{}

	// Enrich course info
	if c, ok := s.courses[session.CourseID]; ok {
		session.CourseCode = c.Code
		session.CourseName = c.Name
	}

	// Create backing AttendanceSession
	baseSess := model.AttendanceSession{
		BaseSyncModel: model.BaseSyncModel{
			ID:        session.ID,
			CreatedAt: now,
			UpdatedAt: now,
		},
		CourseID:       session.CourseID,
		CourseCode:     session.CourseCode,
		CourseName:     session.CourseName,
		ScopeCode:      session.ScopeCode,
		MarkedByUserID: session.MarkedByUserID,
		MarkedByName:   session.MarkedByName,
		SessionDate:    now.Format("2006-01-02"),
		Topic:          fmt.Sprintf("Lecture in %s (Optical Stream)", session.RoomNumber),
		IsFinalized:    false,
		Records:        []model.AttendanceRecord{},
	}
	s.sessions[session.ID] = baseSess

	s.opticalSessions[session.ID] = &session
	s.verifiedBySession[session.ID] = make(map[string]bool)

	return &session, nil
}

func (s *AcademicService) VerifyOpticalAttendance(ctx context.Context, req model.OpticalVerificationRequest) (*model.OpticalVerificationResponse, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	session, ok := s.opticalSessions[req.SessionID]
	if !ok || !session.IsActive {
		return nil, fmt.Errorf("active optical session not found or has concluded")
	}

	nowUnix := time.Now().Unix()
	drift := nowUnix - req.Timestamp
	// Replay / Freshness: frames must be scanned live within 10 seconds (drift > 10 is expired)
	if drift > 10 || drift < -5 {
		return nil, fmt.Errorf("expired optical frame (#%d generated %ds ago). Scan live display", req.Sequence, drift)
	}

	// Compute expected HMAC signature
	mac := hmac.New(sha256.New, []byte(session.SessionSecret))
	dataPayload := fmt.Sprintf("%s:%d:%d:%s", req.SessionID, req.Sequence, req.Timestamp, req.Nonce)
	mac.Write([]byte(dataPayload))
	expectedSig := hex.EncodeToString(mac.Sum(nil))

	// Truncated signature comparison (first 16 hex chars used in QR code for compactness)
	if len(req.Signature) >= 16 && len(expectedSig) >= 16 {
		if req.Signature[:16] != expectedSig[:16] {
			return nil, fmt.Errorf("invalid optical packet cryptographic signature")
		}
	} else if req.Signature != expectedSig {
		return nil, fmt.Errorf("invalid optical packet cryptographic signature")
	}

	// Prevent duplicate scan in same session
	if s.verifiedBySession[req.SessionID][req.StudentID] {
		return nil, fmt.Errorf("attendance already recorded for %s in this session", req.StudentName)
	}

	s.verifiedBySession[req.SessionID][req.StudentID] = true
	now := time.Now().UTC()
	recID := fmt.Sprintf("rec-%s-%s", req.SessionID, req.StudentID)

	record := model.AttendanceRecord{
		BaseSyncModel: model.BaseSyncModel{
			ID:        recID,
			CreatedAt: now,
			UpdatedAt: now,
		},
		SessionID:   req.SessionID,
		StudentID:   req.StudentID,
		StudentName: req.StudentName,
		Handle:      req.Handle,
		Status:      model.StatusPresent,
		Remarks:     fmt.Sprintf("Optical Verified [Frame #%d, Latency %ds]", req.Sequence, drift),
	}

	session.VerifiedRecords = append(session.VerifiedRecords, record)
	s.records[recID] = record

	// Update base session
	if baseSess, exists := s.sessions[req.SessionID]; exists {
		baseSess.Records = append(baseSess.Records, record)
		baseSess.UpdatedAt = now
		s.sessions[req.SessionID] = baseSess
	}

	return &model.OpticalVerificationResponse{
		Verified:     true,
		Message:      "Optical packet verified. Attendance recorded.",
		SessionID:    req.SessionID,
		CourseCode:   session.CourseCode,
		CourseName:   session.CourseName,
		StudentName:  req.StudentName,
		Handle:       req.Handle,
		Sequence:     req.Sequence,
		RecordedAt:   now,
		AttendanceID: recID,
	}, nil
}

func (s *AcademicService) GetOpticalSessionRoster(ctx context.Context, sessionID string) ([]model.AttendanceRecord, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	session, ok := s.opticalSessions[sessionID]
	if !ok {
		return nil, fmt.Errorf("session not found")
	}

	res := make([]model.AttendanceRecord, len(session.VerifiedRecords))
	copy(res, session.VerifiedRecords)
	return res, nil
}

func (s *AcademicService) EndOpticalSession(ctx context.Context, sessionID string) (*model.AttendanceSession, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	session, ok := s.opticalSessions[sessionID]
	if !ok {
		return nil, fmt.Errorf("session not found")
	}

	session.IsActive = false
	now := time.Now().UTC()
	session.ExpiresAt = now

	baseSess, exists := s.sessions[sessionID]
	if exists {
		baseSess.IsFinalized = true
		baseSess.UpdatedAt = now
		s.sessions[sessionID] = baseSess
		return &baseSess, nil
	}

	return nil, nil
}


// ----------------------------------------------------
// DEPARTMENTS & ACADEMIC HIERARCHY (M:N and N:1)
// ----------------------------------------------------

func (s *AcademicService) CreateDepartment(ctx context.Context, req model.CreateDepartmentRequest) (model.Department, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	code := strings.ToUpper(strings.TrimSpace(req.Code))
	if code == "" {
		return model.Department{}, fmt.Errorf("department code is required")
	}
	name := strings.TrimSpace(req.Name)
	if name == "" {
		return model.Department{}, fmt.Errorf("department name is required")
	}

	deptID := fmt.Sprintf("dept-%s", strings.ToLower(code))
	now := time.Now().UTC()

	dept := model.Department{
		BaseSyncModel: model.BaseSyncModel{
			ID:        deptID,
			CreatedAt: now,
			UpdatedAt: now,
		},
		Code:        code,
		Name:        name,
		Description: req.Description,
		HODID:       req.HODID,
		SubjectIDs:  req.SubjectIDs,
		TeacherIDs:  req.TeacherIDs,
		SemesterIDs: req.SemesterIDs,
	}

	// Register M:N Subject relations
	if s.deptSubjects[deptID] == nil {
		s.deptSubjects[deptID] = make(map[string]bool)
	}
	for _, subID := range req.SubjectIDs {
		s.deptSubjects[deptID][subID] = true
		if sub, ok := s.subjects[subID]; ok {
			sub.DepartmentIDs = appendUnique(sub.DepartmentIDs, deptID)
			s.subjects[subID] = sub
		}
	}

	// Register M:N Teacher relations
	if s.deptTeachers[deptID] == nil {
		s.deptTeachers[deptID] = make(map[string]bool)
	}
	for _, tID := range req.TeacherIDs {
		s.deptTeachers[deptID][tID] = true
	}

	// Register M:N Program Semester relations
	if s.deptSemesters[deptID] == nil {
		s.deptSemesters[deptID] = make(map[string]bool)
	}
	for _, semID := range req.SemesterIDs {
		s.deptSemesters[deptID][semID] = true
	}

	dept.SubjectCount = len(s.deptSubjects[deptID])
	dept.TeacherCount = len(s.deptTeachers[deptID])
	dept.SemesterCount = len(s.deptSemesters[deptID])

	s.departments[deptID] = dept
	return dept, nil
}

func (s *AcademicService) ListDepartments(ctx context.Context) ([]model.Department, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []model.Department
	for _, d := range s.departments {
		if !d.IsDeleted {
			d.SubjectCount = len(s.deptSubjects[d.ID])
			d.TeacherCount = len(s.deptTeachers[d.ID])
			d.SemesterCount = len(s.deptSemesters[d.ID])
			result = append(result, d)
		}
	}
	sort.Slice(result, func(i, j int) bool { return result[i].Code < result[j].Code })
	return result, nil
}

func (s *AcademicService) GetDepartmentDetail(ctx context.Context, deptID string, userResolver func(id string) (model.User, bool)) (model.DepartmentDetail, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	dept, ok := s.departments[deptID]
	if !ok || dept.IsDeleted {
		return model.DepartmentDetail{}, fmt.Errorf("department not found")
	}

	var subjects []model.Subject
	for subID := range s.deptSubjects[deptID] {
		if sub, found := s.subjects[subID]; found && !sub.IsDeleted {
			subjects = append(subjects, sub)
		}
	}
	sort.Slice(subjects, func(i, j int) bool { return subjects[i].Code < subjects[j].Code })

	var teachers []model.User
	for tID := range s.deptTeachers[deptID] {
		if userResolver != nil {
			if u, found := userResolver(tID); found && !u.IsDeleted {
				teachers = append(teachers, u)
			}
		}
	}
	sort.Slice(teachers, func(i, j int) bool { return teachers[i].LastName < teachers[j].LastName })

	var semesters []model.Semester
	for semID := range s.deptSemesters[deptID] {
		if sem, found := s.semesters[semID]; found && !sem.IsDeleted {
			sem.StudentCount = len(s.semStudents[sem.ID])
			semesters = append(semesters, sem)
		}
	}
	sort.Slice(semesters, func(i, j int) bool { return semesters[i].SemesterNumber < semesters[j].SemesterNumber })

	dept.SubjectCount = len(subjects)
	dept.TeacherCount = len(teachers)
	dept.SemesterCount = len(semesters)

	return model.DepartmentDetail{
		Department: dept,
		Subjects:   subjects,
		Teachers:   teachers,
		Semesters:  semesters,
	}, nil
}

// ----------------------------------------------------
// PROGRAMS, SEMESTERS & SUBJECTS
// ----------------------------------------------------

func (s *AcademicService) CreateProgram(ctx context.Context, p model.Program) (model.Program, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now().UTC()
	if p.ID == "" {
		p.ID = fmt.Sprintf("prog-%s", strings.ToLower(p.Code))
	}
	p.CreatedAt = now
	p.UpdatedAt = now
	s.programs[p.ID] = p
	return p, nil
}

func (s *AcademicService) ListPrograms(ctx context.Context) ([]model.Program, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []model.Program
	for _, p := range s.programs {
		if !p.IsDeleted {
			result = append(result, p)
		}
	}
	sort.Slice(result, func(i, j int) bool { return result[i].Code < result[j].Code })
	return result, nil
}

func (s *AcademicService) CreateSubject(ctx context.Context, sub model.Subject) (model.Subject, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now().UTC()
	if sub.ID == "" {
		sub.ID = fmt.Sprintf("subj-%s", strings.ToLower(sub.Code))
	}
	sub.CreatedAt = now
	sub.UpdatedAt = now
	s.subjects[sub.ID] = sub
	return sub, nil
}

func (s *AcademicService) ListSubjects(ctx context.Context) ([]model.Subject, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []model.Subject
	for _, sub := range s.subjects {
		if !sub.IsDeleted {
			result = append(result, sub)
		}
	}
	sort.Slice(result, func(i, j int) bool { return result[i].Code < result[j].Code })
	return result, nil
}

func (s *AcademicService) CreateSemester(ctx context.Context, sem model.Semester) (model.Semester, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now().UTC()
	if sem.ID == "" {
		sem.ID = fmt.Sprintf("sem-%s-%d-%s", strings.ToLower(sem.ProgramCode), sem.SemesterNumber, strings.ToLower(sem.Section))
	}
	sem.CreatedAt = now
	sem.UpdatedAt = now
	s.semesters[sem.ID] = sem

	// Register M:N subjects within this semester
	if s.semSubjects[sem.ID] == nil {
		s.semSubjects[sem.ID] = make(map[string]bool)
	}
	for _, subID := range sem.SubjectIDs {
		s.semSubjects[sem.ID][subID] = true
	}

	// Register M:N teachers in this semester
	if s.semTeachers[sem.ID] == nil {
		s.semTeachers[sem.ID] = make(map[string]bool)
	}
	for _, tID := range sem.TeacherIDs {
		s.semTeachers[sem.ID][tID] = true
	}

	return sem, nil
}

func (s *AcademicService) ListSemesters(ctx context.Context) ([]model.Semester, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []model.Semester
	for _, sem := range s.semesters {
		if !sem.IsDeleted {
			sem.StudentCount = len(s.semStudents[sem.ID])
			result = append(result, sem)
		}
	}
	sort.Slice(result, func(i, j int) bool { return result[i].DisplayName < result[j].DisplayName })
	return result, nil
}

func (s *AcademicService) GetSemesterDetail(ctx context.Context, semID string, userResolver func(id string) (model.User, bool)) (model.SemesterDetail, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	sem, ok := s.semesters[semID]
	if !ok || sem.IsDeleted {
		return model.SemesterDetail{}, fmt.Errorf("semester not found")
	}

	var subjects []model.Subject
	for subID := range s.semSubjects[semID] {
		if sub, found := s.subjects[subID]; found && !sub.IsDeleted {
			subjects = append(subjects, sub)
		}
	}
	sort.Slice(subjects, func(i, j int) bool { return subjects[i].Code < subjects[j].Code })

	var teachers []model.User
	for tID := range s.semTeachers[semID] {
		if userResolver != nil {
			if u, found := userResolver(tID); found && !u.IsDeleted {
				teachers = append(teachers, u)
			}
		}
	}
	sort.Slice(teachers, func(i, j int) bool { return teachers[i].LastName < teachers[j].LastName })

	var students []model.User
	for sID := range s.semStudents[semID] {
		if userResolver != nil {
			if u, found := userResolver(sID); found && !u.IsDeleted {
				students = append(students, u)
			}
		}
	}
	sort.Slice(students, func(i, j int) bool { return students[i].CampusHandle < students[j].CampusHandle })

	sem.StudentCount = len(students)
	return model.SemesterDetail{
		Semester: sem,
		Subjects: subjects,
		Teachers: teachers,
		Students: students,
	}, nil
}

func (s *AcademicService) AssignStudentToSemester(ctx context.Context, studentID, semesterID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	// Clear student from any prior semester (Many-to-one strictly enforces 1 semester cohort per student)
	for _, studentMap := range s.semStudents {
		delete(studentMap, studentID)
	}

	if s.semStudents[semesterID] == nil {
		s.semStudents[semesterID] = make(map[string]bool)
	}
	s.semStudents[semesterID][studentID] = true
	return nil
}

func appendUnique(slice []string, val string) []string {
	for _, item := range slice {
		if item == val {
			return slice
		}
	}
	return append(slice, val)
}

// ----------------------------------------------------
// CROSS-PROGRAM SECTIONS (SHARED COHORTS)
// ----------------------------------------------------

func (s *AcademicService) CreateSection(ctx context.Context, req model.CreateSectionRequest) (model.Section, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	name := strings.TrimSpace(req.Name)
	if name == "" {
		return model.Section{}, fmt.Errorf("section name is required")
	}
	if req.SemesterNumber < 1 || req.SemesterNumber > 12 {
		return model.Section{}, fmt.Errorf("invalid semester number")
	}
	if len(req.ProgramIDs) == 0 {
		return model.Section{}, fmt.Errorf("section must be associated with at least one program")
	}

	cleanYear := strings.TrimSpace(req.AcademicYear)
	if cleanYear == "" {
		cleanYear = "2025-2026"
	}

	cleanNameKey := strings.ToLower(strings.ReplaceAll(name, " ", "-"))
	secID := fmt.Sprintf("sec-sem%d-%s", req.SemesterNumber, cleanNameKey)
	now := time.Now().UTC()

	var progNames []string
	for _, pid := range req.ProgramIDs {
		if p, ok := s.programs[pid]; ok {
			progNames = append(progNames, p.Code)
		}
	}

	displayName := fmt.Sprintf("Semester %d - %s (%s)", req.SemesterNumber, name, strings.Join(progNames, ", "))

	sec := model.Section{
		BaseSyncModel: model.BaseSyncModel{
			ID:        secID,
			CreatedAt: now,
			UpdatedAt: now,
		},
		Name:           name,
		SemesterNumber: req.SemesterNumber,
		AcademicYear:   cleanYear,
		DisplayName:    displayName,
		DepartmentID:   req.DepartmentID,
		ProgramIDs:     req.ProgramIDs,
		ProgramNames:   progNames,
		SubjectIDs:     req.SubjectIDs,
		TeacherIDs:     req.TeacherIDs,
	}

	// Register M:N Programs
	if s.secPrograms[secID] == nil {
		s.secPrograms[secID] = make(map[string]bool)
	}
	for _, pid := range req.ProgramIDs {
		s.secPrograms[secID][pid] = true
	}

	// Register M:N Teachers
	if s.secTeachers[secID] == nil {
		s.secTeachers[secID] = make(map[string]bool)
	}
	for _, tid := range req.TeacherIDs {
		s.secTeachers[secID][tid] = true
	}

	// Register default shared allocations for subjects
	s.secSubjects[secID] = nil
	for _, subID := range req.SubjectIDs {
		if sub, ok := s.subjects[subID]; ok {
			s.secSubjects[secID] = append(s.secSubjects[secID], model.SectionSubjectAllocation{
				SubjectID:   sub.ID,
				SubjectCode: sub.Code,
				SubjectName: sub.Name,
				Credits:     sub.Credits,
				ProgramID:   nil, // shared core subject by default
			})
		}
	}

	s.sections[secID] = sec
	return sec, nil
}

func (s *AcademicService) ListSections(ctx context.Context) ([]model.Section, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []model.Section
	for _, sec := range s.sections {
		if !sec.IsDeleted {
			sec.StudentCount = len(s.secStudents[sec.ID])
			var progNames []string
			for pid := range s.secPrograms[sec.ID] {
				if p, ok := s.programs[pid]; ok {
					progNames = append(progNames, p.Code)
				}
			}
			sort.Strings(progNames)
			sec.ProgramNames = progNames
			result = append(result, sec)
		}
	}
	sort.Slice(result, func(i, j int) bool {
		if result[i].SemesterNumber != result[j].SemesterNumber {
			return result[i].SemesterNumber < result[j].SemesterNumber
		}
		return result[i].Name < result[j].Name
	})
	return result, nil
}

func (s *AcademicService) GetSectionDetail(ctx context.Context, secID string, userResolver func(id string) (model.User, bool), studentProgramResolver func(id string) string) (model.SectionDetail, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	sec, ok := s.sections[secID]
	if !ok || sec.IsDeleted {
		return model.SectionDetail{}, fmt.Errorf("section not found")
	}

	// Programs
	var programs []model.Program
	for pid := range s.secPrograms[secID] {
		if p, found := s.programs[pid]; found && !p.IsDeleted {
			programs = append(programs, p)
		}
	}
	sort.Slice(programs, func(i, j int) bool { return programs[i].Code < programs[j].Code })

	// Subjects & Allocations
	allocs := s.secSubjects[secID]
	var subjects []model.Subject
	seenSub := make(map[string]bool)
	for _, a := range allocs {
		if !seenSub[a.SubjectID] {
			seenSub[a.SubjectID] = true
			if sub, found := s.subjects[a.SubjectID]; found {
				subjects = append(subjects, sub)
			}
		}
	}

	// Teachers
	var teachers []model.User
	for tid := range s.secTeachers[secID] {
		if userResolver != nil {
			if u, found := userResolver(tid); found && !u.IsDeleted {
				teachers = append(teachers, u)
			}
		}
	}
	sort.Slice(teachers, func(i, j int) bool { return teachers[i].LastName < teachers[j].LastName })

	// Students & Program breakdown
	var students []model.User
	programBreakdown := make(map[string]int)
	for sid := range s.secStudents[secID] {
		if userResolver != nil {
			if u, found := userResolver(sid); found && !u.IsDeleted {
				students = append(students, u)
			}
		}
		progCode := "General"
		if studentProgramResolver != nil {
			if pCode := studentProgramResolver(sid); pCode != "" {
				progCode = pCode
			}
		} else if pid, ok := s.studentPrograms[sid]; ok {
			if p, ok := s.programs[pid]; ok {
				progCode = p.Code
			}
		}
		programBreakdown[progCode]++
	}
	sort.Slice(students, func(i, j int) bool { return students[i].CampusHandle < students[j].CampusHandle })

	sec.StudentCount = len(students)

	return model.SectionDetail{
		Section:            sec,
		Programs:           programs,
		Subjects:           subjects,
		SubjectAllocations: allocs,
		Teachers:           teachers,
		Students:           students,
		ProgramBreakdown:   programBreakdown,
	}, nil
}

func (s *AcademicService) AssignStudentToSection(ctx context.Context, studentID, sectionID, programID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	// Clear student from previous section cohort (Many-to-One student->section)
	for _, stMap := range s.secStudents {
		delete(stMap, studentID)
	}

	if s.secStudents[sectionID] == nil {
		s.secStudents[sectionID] = make(map[string]bool)
	}
	s.secStudents[sectionID][studentID] = true
	if programID != "" {
		s.studentPrograms[studentID] = programID
	}
	return nil
}

func (s *AcademicService) AllocateSubjectToSection(ctx context.Context, secID string, alloc model.SectionSubjectAllocation) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, ok := s.sections[secID]; !ok {
		return fmt.Errorf("section not found")
	}

	// Update or append
	updated := false
	for i, existing := range s.secSubjects[secID] {
		if existing.SubjectID == alloc.SubjectID && ((existing.ProgramID == nil && alloc.ProgramID == nil) || (existing.ProgramID != nil && alloc.ProgramID != nil && *existing.ProgramID == *alloc.ProgramID)) {
			s.secSubjects[secID][i] = alloc
			updated = true
			break
		}
	}
	if !updated {
		s.secSubjects[secID] = append(s.secSubjects[secID], alloc)
	}
	return nil
}

