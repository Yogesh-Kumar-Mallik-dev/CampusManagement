package model

import "time"

// BaseSyncModel contains audit columns required for delta sync
type BaseSyncModel struct {
	ID        string    `json:"id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	IsDeleted bool      `json:"is_deleted"`
}

// Course represents an academic subject in the catalog
type Course struct {
	BaseSyncModel
	Code              string  `json:"code"` // e.g. CS301
	Name              string  `json:"name"` // Operating Systems
	DepartmentScopeID *string `json:"department_scope_id,omitempty"`
	DepartmentCode    string  `json:"department_code,omitempty"`
	Credits           int     `json:"credits"`
	Semester          int     `json:"semester"`
}

// TimetableSlot represents a recurring scheduled lecture or lab
type TimetableSlot struct {
	BaseSyncModel
	CourseID       string  `json:"course_id"`
	CourseCode     string  `json:"course_code,omitempty"`
	CourseName     string  `json:"course_name,omitempty"`
	ScopeID        string  `json:"scope_id"` // Target cohort (e.g. sec:cse-3a)
	ScopeCode      string  `json:"scope_code,omitempty"`
	InstructorID   *string `json:"instructor_id,omitempty"`
	InstructorName string  `json:"instructor_name,omitempty"`
	DayOfWeek      int     `json:"day_of_week"` // 1 = Monday ... 7 = Sunday
	StartTime      string  `json:"start_time"`  // "09:00"
	EndTime        string  `json:"end_time"`    // "10:00"
	RoomNumber     string  `json:"room_number"` // "LH-201"
	SlotType       string  `json:"slot_type"`   // 'lecture', 'lab', 'tutorial'
}

// AttendanceStatus represents student attendance status
type AttendanceStatus string

const (
	StatusPresent AttendanceStatus = "present"
	StatusAbsent  AttendanceStatus = "absent"
	StatusLate    AttendanceStatus = "late"
	StatusExcused AttendanceStatus = "excused"
)

// AttendanceRecord represents a single student's status for a session
type AttendanceRecord struct {
	BaseSyncModel
	SessionID   string           `json:"session_id"`
	StudentID   string           `json:"student_id"`
	StudentName string           `json:"student_name,omitempty"`
	StudentRoll string           `json:"student_roll,omitempty"`
	Handle      string           `json:"campus_handle,omitempty"`
	Status      AttendanceStatus `json:"status"`
	Remarks     string           `json:"remarks,omitempty"`
}

// AttendanceSession represents a class instance on a specific date
type AttendanceSession struct {
	BaseSyncModel
	TimetableSlotID *string            `json:"timetable_slot_id,omitempty"`
	CourseID        string             `json:"course_id"`
	CourseCode      string             `json:"course_code,omitempty"`
	CourseName      string             `json:"course_name,omitempty"`
	ScopeID         string             `json:"scope_id"`
	ScopeCode       string             `json:"scope_code,omitempty"`
	MarkedByUserID  string             `json:"marked_by_user_id"`
	MarkedByName    string             `json:"marked_by_name,omitempty"`
	SessionDate     string             `json:"session_date"` // YYYY-MM-DD
	Topic           string             `json:"topic,omitempty"`
	IsFinalized     bool               `json:"is_finalized"`
	Records         []AttendanceRecord `json:"records,omitempty"`
}

// AttendanceSummary aggregates attendance percentage for a student
type AttendanceSummary struct {
	CourseID      string  `json:"course_id"`
	CourseCode    string  `json:"course_code"`
	CourseName    string  `json:"course_name"`
	TotalSessions int     `json:"total_sessions"`
	Attended      int     `json:"attended"`
	Percentage    float64 `json:"percentage"`
}

// Notice represents a scoped or campus-wide announcement
type Notice struct {
	BaseSyncModel
	Title           string     `json:"title"`
	Content         string     `json:"content"`
	Category        string     `json:"category"` // 'academic', 'exam', 'urgent', 'event', 'hostel'
	PublisherID     *string    `json:"publisher_id,omitempty"`
	PublisherName   string     `json:"publisher_name,omitempty"`
	TargetScopeID   *string    `json:"target_scope_id,omitempty"`
	TargetScopeCode string     `json:"target_scope_code,omitempty"` // empty or "global" = campus-wide
	Priority        string     `json:"priority"`                    // 'normal', 'high', 'urgent'
	PublishedAt     time.Time  `json:"published_at"`
	ExpiresAt       *time.Time `json:"expires_at,omitempty"`
}

// OfflineAttendanceBatch is pushed by clients (mobile/desktop/web) when coming back online
type OfflineAttendanceBatch struct {
	Sessions []AttendanceSession `json:"sessions"`
}

// DeltaSyncResponse returns all delta updates for a client since a given timestamp
type DeltaSyncResponse struct {
	ServerTime         time.Time           `json:"server_time"`
	Courses            []Course            `json:"courses"`
	TimetableSlots     []TimetableSlot     `json:"timetable_slots"`
	AttendanceSessions []AttendanceSession `json:"attendance_sessions"`
	AttendanceRecords  []AttendanceRecord  `json:"attendance_records"`
	Notices            []Notice            `json:"notices"`
}
