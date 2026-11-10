package service

import (
	"context"
	"errors"
	"fmt"
	"math"
	"sync"
	"time"

	"campus/backend/internal/model"
)

var (
	ErrAssessmentRecordNotFound = errors.New("assessment record not found")
	ErrMarksAlreadyFrozen       = errors.New("marks for this subject cohort are frozen and cannot be modified")
	ErrInvalidMarkRange         = errors.New("entered marks exceed prescribed maximum bounds")
	ErrUnauthorizedFreezer      = errors.New("only authorized HOD or Exam In-Charge can freeze internal marks")
)

// SessionalService manages continuous assessment under AKTU university regulations
type SessionalService struct {
	mu        sync.RWMutex
	records   map[string]*model.InternalAssessmentRecord
	schedules []model.SessionalExamSchedule
	permSvc   PermissionServiceInterface
}

// NewSessionalService initializes the sessional examination service with default mock data
func NewSessionalService(permSvc PermissionServiceInterface) *SessionalService {
	s := &SessionalService{
		records:   make(map[string]*model.InternalAssessmentRecord),
		schedules: make([]model.SessionalExamSchedule, 0),
		permSvc:   permSvc,
	}
	s.seedDefaultData()
	return s
}

func (s *SessionalService) seedDefaultData() {
	now := time.Now()

	// Seed AKTU Sessional Schedules (CT-1, CT-2, PUT)
	s.schedules = []model.SessionalExamSchedule{
		{
			BaseSyncModel:   model.BaseSyncModel{ID: "sch-ct1-cs301", CreatedAt: now, UpdatedAt: now},
			ExamType:        "CT-1",
			SubjectCode:     "CS301",
			SubjectName:     "Operating Systems",
			SemesterNumber:  5,
			ExamDate:        "2025-11-24",
			TimeSlot:        "10:00 AM - 11:30 AM",
			HallNumber:      "LT-101",
			TotalCapacity:   60,
			InvigilatorName: "Prof. Neha Sharma",
			RollRange:       "2100970100001 - 2100970100060",
		},
		{
			BaseSyncModel:   model.BaseSyncModel{ID: "sch-ct1-cs302", CreatedAt: now, UpdatedAt: now},
			ExamType:        "CT-1",
			SubjectCode:     "CS302",
			SubjectName:     "Database Management Systems",
			SemesterNumber:  5,
			ExamDate:        "2025-11-25",
			TimeSlot:        "10:00 AM - 11:30 AM",
			HallNumber:      "LT-101",
			TotalCapacity:   60,
			InvigilatorName: "Dr. Arun Kumar (HOD)",
			RollRange:       "2100970100001 - 2100970100060",
		},
		{
			BaseSyncModel:   model.BaseSyncModel{ID: "sch-ct1-cs303", CreatedAt: now, UpdatedAt: now},
			ExamType:        "CT-1",
			SubjectCode:     "CS303",
			SubjectName:     "Design & Analysis of Algorithms",
			SemesterNumber:  5,
			ExamDate:        "2025-11-26",
			TimeSlot:        "10:00 AM - 11:30 AM",
			HallNumber:      "LT-102",
			TotalCapacity:   60,
			InvigilatorName: "Prof. Neha Sharma",
			RollRange:       "2100970100001 - 2100970100060",
		},
		{
			BaseSyncModel:   model.BaseSyncModel{ID: "sch-ct2-cs301", CreatedAt: now, UpdatedAt: now},
			ExamType:        "CT-2",
			SubjectCode:     "CS301",
			SubjectName:     "Operating Systems",
			SemesterNumber:  5,
			ExamDate:        "2025-12-15",
			TimeSlot:        "02:00 PM - 03:30 PM",
			HallNumber:      "LT-101",
			TotalCapacity:   60,
			InvigilatorName: "Prof. Neha Sharma",
			RollRange:       "2100970100001 - 2100970100060",
		},
		{
			BaseSyncModel:   model.BaseSyncModel{ID: "sch-put-cs301", CreatedAt: now, UpdatedAt: now},
			ExamType:        "PUT",
			SubjectCode:     "CS301",
			SubjectName:     "Operating Systems (Pre-University Test)",
			SemesterNumber:  5,
			ExamDate:        "2026-01-05",
			TimeSlot:        "09:30 AM - 12:30 PM",
			HallNumber:      "Main Auditorium Hall A",
			TotalCapacity:   120,
			InvigilatorName: "Dr. Arun Kumar (HOD)",
			RollRange:       "2100970100001 - 2100970100120",
		},
	}

	// Seed Cohort Assessment Records
	students := []struct {
		ID     string
		Name   string
		RollNo string
	}{
		{"usr-harish_2025_l_btech_1", "Harish Kumar", "2100970100045"},
		{"usr-priya_singh_cse", "Priya Singh", "2100970100046"},
		{"usr-rahul_verma_cse", "Rahul Verma", "2100970100047"},
		{"usr-ananya_gupta_cse", "Ananya Gupta", "2100970100048"},
		{"usr-vikas_yadav_cse", "Vikas Yadav", "2100970100049"},
	}

	subjects := []struct {
		Code        string
		Name        string
		IsPractical bool
	}{
		{"CS301", "Operating Systems", false},
		{"CS302", "Database Management Systems", false},
		{"CS303", "Design & Analysis of Algorithms", false},
		{"CS301L", "Operating Systems Lab", true},
	}

	mockScores := map[string]map[string][4]float64{
		// [CT1, CT2, PUT, TA] for theory OR [LabCont, LabViva, LabAtt, 0] for practical
		"usr-harish_2025_l_btech_1": {
			"CS301":  {26.0, 24.0, 78.0, 8.5},
			"CS302":  {28.0, 27.0, 82.0, 9.0},
			"CS303":  {22.0, 25.0, 70.0, 8.0},
			"CS301L": {18.0, 17.5, 9.0, 0.0},
		},
		"usr-priya_singh_cse": {
			"CS301":  {29.0, 28.5, 91.0, 9.5},
			"CS302":  {27.0, 26.0, 84.0, 9.0},
			"CS303":  {28.0, 29.0, 88.0, 9.5},
			"CS301L": {19.0, 19.0, 9.5, 0.0},
		},
		"usr-rahul_verma_cse": {
			"CS301":  {18.0, 16.0, 52.0, 7.0},
			"CS302":  {19.0, 15.0, 48.0, 6.5},
			"CS303":  {14.0, 16.0, 45.0, 6.0},
			"CS301L": {14.0, 13.0, 7.5, 0.0},
		},
		"usr-ananya_gupta_cse": {
			"CS301":  {25.0, 23.0, 75.0, 8.0},
			"CS302":  {26.0, 24.0, 76.0, 8.5},
			"CS303":  {24.0, 22.0, 72.0, 8.0},
			"CS301L": {17.0, 18.0, 8.5, 0.0},
		},
		"usr-vikas_yadav_cse": {
			"CS301":  {12.0, 10.0, 34.0, 5.0},
			"CS302":  {11.0, 9.0, 30.0, 4.5},
			"CS303":  {10.0, 8.0, 28.0, 4.0},
			"CS301L": {11.0, 10.0, 6.0, 0.0},
		},
	}

	for _, st := range students {
		for _, sub := range subjects {
			recID := fmt.Sprintf("rec-%s-%s", sub.Code, st.RollNo)
			rec := model.InternalAssessmentRecord{
				BaseSyncModel:    model.BaseSyncModel{ID: recID, CreatedAt: now.Add(-10 * 24 * time.Hour), UpdatedAt: now},
				StudentID:        st.ID,
				StudentName:      st.Name,
				UniversityRollNo: st.RollNo,
				SubjectCode:      sub.Code,
				SubjectName:      sub.Name,
				SemesterNumber:   5,
				Section:          "Section B",
				IsPractical:      sub.IsPractical,
				Status:           "submitted",
			}

			scores := mockScores[st.ID][sub.Code]
			if sub.IsPractical {
				rec.LabContinuousScore = scores[0]
				rec.LabVivaScore = scores[1]
				rec.LabAttendanceScore = scores[2]
			} else {
				rec.CT1Score = scores[0]
				rec.CT2Score = scores[1]
				rec.PUTScore = scores[2]
				rec.TAScore = scores[3]
			}

			rec.Recalculate()
			s.records[recID] = &rec
		}
	}
}

// GetRecords retrieves student sessional internal records
func (s *SessionalService) GetRecords(ctx context.Context, studentID, subjectCode string, semester int) ([]model.InternalAssessmentRecord, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []model.InternalAssessmentRecord
	for _, rec := range s.records {
		if studentID != "" && rec.StudentID != studentID && rec.UniversityRollNo != studentID {
			continue
		}
		if subjectCode != "" && rec.SubjectCode != subjectCode {
			continue
		}
		if semester > 0 && rec.SemesterNumber != semester {
			continue
		}
		result = append(result, *rec)
	}
	return result, nil
}

// RecordMarks records or updates marks entered by faculty with strict AKTU range checking
func (s *SessionalService) RecordMarks(ctx context.Context, req model.UpdateMarksRequest) (*model.InternalAssessmentRecord, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	var target *model.InternalAssessmentRecord
	if req.RecordID != "" {
		target = s.records[req.RecordID]
	} else if req.SubjectCode != "" && req.StudentID != "" {
		for _, r := range s.records {
			if r.SubjectCode == req.SubjectCode && (r.StudentID == req.StudentID || r.UniversityRollNo == req.StudentID) {
				target = r
				break
			}
		}
	}

	if target == nil {
		return nil, ErrAssessmentRecordNotFound
	}

	if target.IsFrozen {
		return nil, ErrMarksAlreadyFrozen
	}

	// Validate bounds
	if req.CT1Score != nil {
		if *req.CT1Score < 0 || *req.CT1Score > 30.0 {
			return nil, fmt.Errorf("%w: CT-1 must be between 0 and 30", ErrInvalidMarkRange)
		}
		target.CT1Score = *req.CT1Score
	}
	if req.CT2Score != nil {
		if *req.CT2Score < 0 || *req.CT2Score > 30.0 {
			return nil, fmt.Errorf("%w: CT-2 must be between 0 and 30", ErrInvalidMarkRange)
		}
		target.CT2Score = *req.CT2Score
	}
	if req.PUTScore != nil {
		if *req.PUTScore < 0 || *req.PUTScore > 100.0 {
			return nil, fmt.Errorf("%w: PUT must be between 0 and 100", ErrInvalidMarkRange)
		}
		target.PUTScore = *req.PUTScore
	}
	if req.TAScore != nil {
		if *req.TAScore < 0 || *req.TAScore > 10.0 {
			return nil, fmt.Errorf("%w: Teacher Assessment must be between 0 and 10", ErrInvalidMarkRange)
		}
		target.TAScore = *req.TAScore
	}
	if req.LabContinuousScore != nil {
		if *req.LabContinuousScore < 0 || *req.LabContinuousScore > 20.0 {
			return nil, fmt.Errorf("%w: Lab Continuous must be between 0 and 20", ErrInvalidMarkRange)
		}
		target.LabContinuousScore = *req.LabContinuousScore
	}
	if req.LabVivaScore != nil {
		if *req.LabVivaScore < 0 || *req.LabVivaScore > 20.0 {
			return nil, fmt.Errorf("%w: Lab Viva must be between 0 and 20", ErrInvalidMarkRange)
		}
		target.LabVivaScore = *req.LabVivaScore
	}
	if req.LabAttendanceScore != nil {
		if *req.LabAttendanceScore < 0 || *req.LabAttendanceScore > 10.0 {
			return nil, fmt.Errorf("%w: Lab Attendance must be between 0 and 10", ErrInvalidMarkRange)
		}
		target.LabAttendanceScore = *req.LabAttendanceScore
	}
	if req.Remarks != "" {
		target.Remarks = req.Remarks
	}

	target.UpdatedAt = time.Now()
	target.Recalculate()
	return target, nil
}

// FreezeMarks locks marks permanently for submission to the AKTU university portal
func (s *SessionalService) FreezeMarks(ctx context.Context, req model.FreezeInternalMarksRequest) (*model.AKTUInternalAwardList, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now()
	var matched []*model.InternalAssessmentRecord
	for _, rec := range s.records {
		if rec.SubjectCode == req.SubjectCode && (req.Semester <= 0 || rec.SemesterNumber == req.Semester) {
			rec.IsFrozen = true
			rec.FrozenBy = req.FrozenBy
			rec.FrozenAt = &now
			rec.Status = "frozen"
			if req.Remarks != "" {
				rec.Remarks = req.Remarks
			}
			matched = append(matched, rec)
		}
	}

	if len(matched) == 0 {
		return nil, ErrAssessmentRecordNotFound
	}

	// Compile award list
	return s.compileAwardListLocked(req.SubjectCode, req.Semester, matched, req.FrozenBy, now), nil
}

// GetAwardList compiles the statistics and audit view for the HOD or faculty
func (s *SessionalService) GetAwardList(ctx context.Context, subjectCode string, semester int) (*model.AKTUInternalAwardList, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var matched []*model.InternalAssessmentRecord
	for _, rec := range s.records {
		if rec.SubjectCode == subjectCode && (semester <= 0 || rec.SemesterNumber == semester) {
			matched = append(matched, rec)
		}
	}

	if len(matched) == 0 {
		return nil, ErrAssessmentRecordNotFound
	}

	frozenBy := ""
	var frozenAt time.Time
	for _, m := range matched {
		if m.IsFrozen {
			frozenBy = m.FrozenBy
			if m.FrozenAt != nil {
				frozenAt = *m.FrozenAt
			}
			break
		}
	}

	return s.compileAwardListLocked(subjectCode, semester, matched, frozenBy, frozenAt), nil
}

func (s *SessionalService) compileAwardListLocked(subjectCode string, semester int, list []*model.InternalAssessmentRecord, frozenBy string, frozenAt time.Time) *model.AKTUInternalAwardList {
	total := len(list)
	if total == 0 {
		return &model.AKTUInternalAwardList{}
	}

	isPractical := list[0].IsPractical
	subjectName := list[0].SubjectName
	maxMarks := 30.0
	if isPractical {
		maxMarks = 50.0
	}

	passThreshold := maxMarks * 0.40 // 40% passing standard
	sum := 0.0
	highest := -1.0
	lowest := 999.0
	passCount := 0
	deficitCount := 0
	recordsCopy := make([]model.InternalAssessmentRecord, 0, total)
	isAllFrozen := true

	for _, r := range list {
		recordsCopy = append(recordsCopy, *r)
		score := r.TotalInternalMarks
		sum += score
		if score > highest {
			highest = score
		}
		if score < lowest {
			lowest = score
		}
		if score >= passThreshold {
			passCount++
		} else {
			deficitCount++
		}
		if !r.IsFrozen {
			isAllFrozen = false
		}
	}

	if lowest > highest {
		lowest = 0.0
	}
	if highest < 0 {
		highest = 0.0
	}

	avg := 0.0
	passPct := 0.0
	if total > 0 {
		avg = math.Round((sum/float64(total))*10) / 10
		passPct = math.Round((float64(passCount)/float64(total))*1000) / 10
	}

	var sig string
	if isAllFrozen && frozenBy != "" {
		sig = model.ComputeAwardListSignature(subjectCode, semester, recordsCopy, frozenBy, frozenAt)
	}

	var frozenAtPtr *time.Time
	if !frozenAt.IsZero() {
		frozenAtPtr = &frozenAt
	}

	return &model.AKTUInternalAwardList{
		DepartmentCode:   "CSE",
		DepartmentName:   "Computer Science & Engineering",
		ProgramName:      "Bachelor of Technology (B.Tech)",
		SemesterNumber:   semester,
		SubjectCode:      subjectCode,
		SubjectName:      subjectName,
		AcademicSession:  "2025-2026",
		IsPractical:      isPractical,
		MaxInternalMarks: maxMarks,
		TotalStudents:    total,
		PassCount:        passCount,
		FailCount:        total - passCount,
		PassPercentage:   passPct,
		AverageMarks:     avg,
		HighestMarks:     highest,
		LowestMarks:      lowest,
		DeficitCount:     deficitCount,
		IsFrozen:         isAllFrozen,
		FrozenBy:         frozenBy,
		FrozenAt:         frozenAtPtr,
		DigitalSignature: sig,
		Records:          recordsCopy,
	}
}

// GetSchedules returns datesheet schedules
func (s *SessionalService) GetSchedules(ctx context.Context, semester int, examType string) ([]model.SessionalExamSchedule, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []model.SessionalExamSchedule
	for _, sc := range s.schedules {
		if semester > 0 && sc.SemesterNumber != semester {
			continue
		}
		if examType != "" && sc.ExamType != examType {
			continue
		}
		result = append(result, sc)
	}
	return result, nil
}

// GetSeatingLayout generates seating arrangements for a given hall and exam type
func (s *SessionalService) GetSeatingLayout(ctx context.Context, hallNumber, examType string) ([]model.DeskSeatingAllocation, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if hallNumber == "" {
		hallNumber = "LT-101"
	}
	if examType == "" {
		examType = "CT-1"
	}

	allocations := []model.DeskSeatingAllocation{
		{
			DeskNumber:    "D-01",
			HallNumber:    hallNumber,
			SeatIndex:     1,
			StudentRollNo: "2100970100045",
			StudentName:   "Harish Kumar",
			SubjectCode:   "CS301",
			SubjectName:   "Operating Systems",
			ExamType:      examType,
		},
		{
			DeskNumber:    "D-02",
			HallNumber:    hallNumber,
			SeatIndex:     2,
			StudentRollNo: "2100970100046",
			StudentName:   "Priya Singh",
			SubjectCode:   "CS301",
			SubjectName:   "Operating Systems",
			ExamType:      examType,
		},
		{
			DeskNumber:    "D-03",
			HallNumber:    hallNumber,
			SeatIndex:     3,
			StudentRollNo: "2100970100047",
			StudentName:   "Rahul Verma",
			SubjectCode:   "CS301",
			SubjectName:   "Operating Systems",
			ExamType:      examType,
		},
		{
			DeskNumber:    "D-04",
			HallNumber:    hallNumber,
			SeatIndex:     4,
			StudentRollNo: "2100970100048",
			StudentName:   "Ananya Gupta",
			SubjectCode:   "CS301",
			SubjectName:   "Operating Systems",
			ExamType:      examType,
		},
		{
			DeskNumber:    "D-05",
			HallNumber:    hallNumber,
			SeatIndex:     5,
			StudentRollNo: "2100970100049",
			StudentName:   "Vikas Yadav",
			SubjectCode:   "CS301",
			SubjectName:   "Operating Systems",
			ExamType:      examType,
		},
	}

	return allocations, nil
}
