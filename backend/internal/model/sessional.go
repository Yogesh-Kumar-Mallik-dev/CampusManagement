package model

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"math"
	"time"
)

// InternalAssessmentRecord stores the continuous sessional and internal assessment
// evaluation of a student for an AKTU affiliated course module.
type InternalAssessmentRecord struct {
	BaseSyncModel
	StudentID          string     `json:"student_id"`
	StudentName        string     `json:"student_name"`
	UniversityRollNo   string     `json:"university_roll_no"`
	SubjectCode        string     `json:"subject_code"` // e.g. CS301, CS301L
	SubjectName        string     `json:"subject_name"`
	SemesterNumber     int        `json:"semester_number"`
	Section            string     `json:"section"`
	IsPractical        bool       `json:"is_practical"`
	CT1Score           float64    `json:"ct1_score"`            // Max 30
	CT2Score           float64    `json:"ct2_score"`            // Max 30
	PUTScore           float64    `json:"put_score"`            // Pre-University Test (Max 100)
	TAScore            float64    `json:"ta_score"`             // Teacher Assessment (Max 10: attendance + assignments)
	LabContinuousScore float64    `json:"lab_continuous_score"` // Max 20: continuous record / experiment work
	LabVivaScore       float64    `json:"lab_viva_score"`       // Max 20: internal viva & test
	LabAttendanceScore float64    `json:"lab_attendance_score"` // Max 10: attendance & lab discipline
	CalculatedSessional float64   `json:"calculated_sessional"` // Theory: out of 20; Practical: out of 50
	TotalInternalMarks float64    `json:"total_internal_marks"` // Theory: out of 30; Practical: out of 50
	MaxInternalMarks   float64    `json:"max_internal_marks"`   // 30 for theory, 50 for practical
	FormulaUsed        string     `json:"formula_used"`
	IsFrozen           bool       `json:"is_frozen"`
	FrozenBy           string     `json:"frozen_by,omitempty"`
	FrozenAt           *time.Time `json:"frozen_at,omitempty"`
	Status             string     `json:"status"` // 'draft', 'submitted', 'frozen'
	Remarks            string     `json:"remarks,omitempty"`
}

// Recalculate applies standard AKTU internal mark computation formulas:
// - Theory Course (Total 30 Marks):
//     Sessional (20 Marks) = ((CT1 + CT2) / 2) * (20 / 30) = (CT1 + CT2) / 3
//     Total Internal = Sessional (20) + Teacher Assessment TA (10)
// - Practical Course (Total 50 Marks):
//     Total Internal = Lab Work Continuous (20) + Viva/Quiz (20) + Attendance/Conduct (10)
func (r *InternalAssessmentRecord) Recalculate() {
	if r.IsPractical {
		r.MaxInternalMarks = 50.0
		labCont := math.Min(math.Max(0, r.LabContinuousScore), 20.0)
		labViva := math.Min(math.Max(0, r.LabVivaScore), 20.0)
		labAtt := math.Min(math.Max(0, r.LabAttendanceScore), 10.0)

		r.LabContinuousScore = labCont
		r.LabVivaScore = labViva
		r.LabAttendanceScore = labAtt

		tot := labCont + labViva + labAtt
		r.CalculatedSessional = roundToOneDecimal(tot)
		r.TotalInternalMarks = roundToOneDecimal(tot)
		r.FormulaUsed = "Lab Continuous (20) + Internal Viva (20) + Lab Conduct (10) [Max 50]"
	} else {
		r.MaxInternalMarks = 30.0
		ct1 := math.Min(math.Max(0, r.CT1Score), 30.0)
		ct2 := math.Min(math.Max(0, r.CT2Score), 30.0)
		ta := math.Min(math.Max(0, r.TAScore), 10.0)

		r.CT1Score = ct1
		r.CT2Score = ct2
		r.TAScore = ta

		// AKTU Theory Formula: ((CT1 + CT2) / 2) * (20 / 30) = (CT1 + CT2) / 3.0
		sessional20 := (ct1 + ct2) / 3.0
		if sessional20 > 20.0 {
			sessional20 = 20.0
		}
		r.CalculatedSessional = roundToOneDecimal(sessional20)
		tot := sessional20 + ta
		if tot > 30.0 {
			tot = 30.0
		}
		r.TotalInternalMarks = roundToOneDecimal(tot)
		r.FormulaUsed = "((CT1 + CT2) / 2) * (20/30) + Teacher Assessment (10) [Max 30]"
	}
}

func roundToOneDecimal(val float64) float64 {
	return math.Round(val*10) / 10
}

// SessionalExamSchedule represents an entry in the sessional / PUT datesheet
type SessionalExamSchedule struct {
	BaseSyncModel
	ExamType        string `json:"exam_type"`        // 'CT-1', 'CT-2', 'PUT'
	SubjectCode     string `json:"subject_code"`     // e.g. CS301
	SubjectName     string `json:"subject_name"`     // e.g. Operating Systems
	SemesterNumber  int    `json:"semester_number"`  // 5
	ExamDate        string `json:"exam_date"`        // YYYY-MM-DD e.g. 2025-11-24
	TimeSlot        string `json:"time_slot"`        // e.g. 10:00 AM - 11:30 AM
	HallNumber      string `json:"hall_number"`      // e.g. LT-101
	TotalCapacity   int    `json:"total_capacity"`   // e.g. 60
	InvigilatorName string `json:"invigilator_name"` // e.g. Prof. Neha Sharma
	RollRange       string `json:"roll_range"`       // e.g. 2100970100001 - 2100970100060
}

// DeskSeatingAllocation represents an assigned exam hall bench seat
type DeskSeatingAllocation struct {
	DeskNumber     string `json:"desk_number"`     // e.g. D-01
	HallNumber     string `json:"hall_number"`     // e.g. LT-101
	SeatIndex      int    `json:"seat_index"`      // 1 through Capacity
	StudentRollNo  string `json:"student_roll_no"` // e.g. 2100970100045
	StudentName    string `json:"student_name"`
	SubjectCode    string `json:"subject_code"`
	SubjectName    string `json:"subject_name"`
	ExamType       string `json:"exam_type"`
}

// AKTUInternalAwardList compiles the complete official award sheet for submission
// to the AKTU university portal, including HOD freeze sign-off and statistical KPIs.
type AKTUInternalAwardList struct {
	DepartmentCode   string                     `json:"department_code"`
	DepartmentName   string                     `json:"department_name"`
	ProgramName      string                     `json:"program_name"`
	SemesterNumber   int                        `json:"semester_number"`
	SubjectCode      string                     `json:"subject_code"`
	SubjectName      string                     `json:"subject_name"`
	AcademicSession  string                     `json:"academic_session"`
	IsPractical      bool                       `json:"is_practical"`
	MaxInternalMarks float64                    `json:"max_internal_marks"`
	TotalStudents    int                        `json:"total_students"`
	PassCount        int                        `json:"pass_count"`
	FailCount        int                        `json:"fail_count"`
	PassPercentage   float64                    `json:"pass_percentage"`
	AverageMarks     float64                    `json:"average_marks"`
	HighestMarks     float64                    `json:"highest_marks"`
	LowestMarks      float64                    `json:"lowest_marks"`
	DeficitCount     int                        `json:"deficit_count"` // Scored < 40% internal threshold
	IsFrozen         bool                       `json:"is_frozen"`
	FrozenBy         string                     `json:"frozen_by,omitempty"`
	FrozenAt         *time.Time                 `json:"frozen_at,omitempty"`
	DigitalSignature string                     `json:"digital_signature,omitempty"`
	Records          []InternalAssessmentRecord `json:"records"`
}

// ComputeAwardListSignature generates an immutable SHA256 checksum over the award list
func ComputeAwardListSignature(subjectCode string, sem int, records []InternalAssessmentRecord, frozenBy string, t time.Time) string {
	raw := fmt.Sprintf("%s|%d|%s|%s", subjectCode, sem, frozenBy, t.Format(time.RFC3339))
	for _, r := range records {
		raw += fmt.Sprintf("|%s:%.1f", r.UniversityRollNo, r.TotalInternalMarks)
	}
	hash := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(hash[:])
}

// UpdateMarksRequest payload for faculty marks entry
type UpdateMarksRequest struct {
	RecordID           string   `json:"record_id"`
	SubjectCode        string   `json:"subject_code"`
	StudentID          string   `json:"student_id"`
	CT1Score           *float64 `json:"ct1_score,omitempty"`
	CT2Score           *float64 `json:"ct2_score,omitempty"`
	PUTScore           *float64 `json:"put_score,omitempty"`
	TAScore            *float64 `json:"ta_score,omitempty"`
	LabContinuousScore *float64 `json:"lab_continuous_score,omitempty"`
	LabVivaScore       *float64 `json:"lab_viva_score,omitempty"`
	LabAttendanceScore *float64 `json:"lab_attendance_score,omitempty"`
	Remarks            string   `json:"remarks,omitempty"`
	EnteredBy          string   `json:"entered_by"`
}

// FreezeInternalMarksRequest payload for HOD approval and freeze
type FreezeInternalMarksRequest struct {
	SubjectCode string `json:"subject_code"`
	Semester    int    `json:"semester"`
	FrozenBy    string `json:"frozen_by"` // HOD or Exam Controller user handle
	Remarks     string `json:"remarks,omitempty"`
}
