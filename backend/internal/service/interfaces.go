package service

import (
	"context"
	"time"

	"campus/backend/internal/model"
)

// PermissionServiceInterface abstracts role and scope authorization
type PermissionServiceInterface interface {
	AddMemoryRole(role model.Role)
	AddMemoryScope(scope model.Scope)
	AssignRole(ctx context.Context, userID, roleCode, scopeCode string, validUntil *time.Time) error
	RevokeAllUserRoles(ctx context.Context, userID string) error
	GetUserRoles(userID string) []model.UserRoleAssignment
	GetUserPermissions(userID string) []string
	Can(ctx context.Context, userID, permissionCode, requestedScope string) (bool, string)
}

// AcademicServiceInterface abstracts curriculum, timetables, attendance, departments, and sections
type AcademicServiceInterface interface {
	CreateCourse(ctx context.Context, course model.Course) (model.Course, error)
	ListCourses(ctx context.Context) ([]model.Course, error)
	CreateTimetableSlot(ctx context.Context, slot model.TimetableSlot) (model.TimetableSlot, error)
	UpdateTimetableSlot(ctx context.Context, slot model.TimetableSlot) (model.TimetableSlot, error)
	DeleteTimetableSlot(ctx context.Context, id string) error
	GetTimetableForScope(ctx context.Context, scopeCode string) ([]model.TimetableSlot, error)
	CheckTimetableConflicts(ctx context.Context, slot model.TimetableSlot) ([]model.TimetableConflict, error)
	DeclareDayOff(ctx context.Context, req model.DayOffRequest) error
	RestoreDaySchedule(ctx context.Context, req model.RestoreDayRequest) error
	SyncAttendanceBatch(ctx context.Context, markedByUserID string, batch model.OfflineAttendanceBatch) ([]model.AttendanceSession, error)
	GetStudentAttendanceSummary(ctx context.Context, studentID string) ([]model.AttendanceSummary, error)
	PublishNotice(ctx context.Context, notice model.Notice) (model.Notice, error)
	GetTargetedNotices(ctx context.Context, userScopes []string) ([]model.Notice, error)
	GetDeltaSync(ctx context.Context, since time.Time, userScopes []string) (model.DeltaSyncResponse, error)
	StartOpticalSession(ctx context.Context, session model.OpticalAttendanceSession) (*model.OpticalAttendanceSession, error)
	VerifyOpticalAttendance(ctx context.Context, req model.OpticalVerificationRequest) (*model.OpticalVerificationResponse, error)
	GetOpticalSessionRoster(ctx context.Context, sessionID string) ([]model.AttendanceRecord, error)
	EndOpticalSession(ctx context.Context, sessionID string) (*model.AttendanceSession, error)
	CreateDepartment(ctx context.Context, req model.CreateDepartmentRequest) (model.Department, error)
	ListDepartments(ctx context.Context) ([]model.Department, error)
	GetDepartmentDetail(ctx context.Context, deptID string, userResolver func(id string) (model.User, bool)) (model.DepartmentDetail, error)
	CreateProgram(ctx context.Context, p model.Program) (model.Program, error)
	UpdateProgram(ctx context.Context, p model.Program) (model.Program, error)
	ListPrograms(ctx context.Context) ([]model.Program, error)
	CreateSubject(ctx context.Context, sub model.Subject) (model.Subject, error)
	ListSubjects(ctx context.Context) ([]model.Subject, error)
	ReviseSyllabus(ctx context.Context, req model.ReviseSyllabusRequest) (model.SyllabusVersion, error)
	GetSubjectSyllabusAuditTrail(ctx context.Context, subjectID string) ([]model.SyllabusVersion, error)
	CreateSemester(ctx context.Context, sem model.Semester) (model.Semester, error)
	ListSemesters(ctx context.Context) ([]model.Semester, error)
	GetSemesterDetail(ctx context.Context, semID string, userResolver func(id string) (model.User, bool)) (model.SemesterDetail, error)
	AssignStudentToSemester(ctx context.Context, studentID, semesterID string) error
	CreateSection(ctx context.Context, req model.CreateSectionRequest) (model.Section, error)
	ListSections(ctx context.Context) ([]model.Section, error)
	GetSectionDetail(ctx context.Context, secID string, userResolver func(id string) (model.User, bool), studentProgramResolver func(id string) string) (model.SectionDetail, error)
	AssignStudentToSection(ctx context.Context, studentID, sectionID, programID string) error
	TransferStudentSection(ctx context.Context, studentID, targetSectionID string) error
	MergeSectionCohorts(ctx context.Context, sourceSectionID, targetSectionID string) (int, error)
	AllocateSubjectToSection(ctx context.Context, secID string, alloc model.SectionSubjectAllocation) error
	CreateLabBatch(ctx context.Context, req model.CreateLabBatchRequest) (model.LabBatch, error)
	AutoPartitionLabBatches(ctx context.Context, req model.AutoPartitionBatchesRequest) ([]model.LabBatch, error)
	AssignStudentToLabBatch(ctx context.Context, batchID, studentID string) error
	GetSectionLabBatches(ctx context.Context, sectionID string) ([]model.LabBatch, error)
	AssignFacultyAllocation(ctx context.Context, req model.AssignFacultyAllocationRequest, userResolver func(id string) (model.User, bool)) (model.FacultyAllocation, error)
	RemoveFacultyAllocation(ctx context.Context, allocationID string) error
	GetSectionFacultyAllocations(ctx context.Context, sectionID string) ([]model.FacultyAllocation, error)
	GetFacultyWorkloadSummary(ctx context.Context, teacherID string, userResolver func(id string) (model.User, bool)) (model.FacultyWorkloadSummary, error)
	GetAllFacultyWorkloadSummaries(ctx context.Context, userResolver func(id string) (model.User, bool), teacherProvider func() []model.User) ([]model.FacultyWorkloadSummary, error)
}

// HostelServiceInterface abstracts hostel rooms, fixtures, and occupants
type HostelServiceInterface interface {
	CreateRoom(roomNumber int, blockName string) (*model.HostelRoom, error)
	GetRooms() ([]model.HostelRoom, error)
	GetRoomByNumber(roomNumber int) (*model.HostelRoom, error)
	AddAsset(roomNumber int, assetType string, serialNumber string, condition string) (*model.HostelAsset, error)
	RemoveAsset(roomNumber int, assetID string) error
	AssignOccupant(roomNumber int, userID string, handle string, name string) (*model.HostelOccupant, error)
	RemoveOccupant(roomNumber int, identifier string) error
	UpdateRoom(originalRoomNumber int, newRoomNumber int, blockName string) (*model.HostelRoom, error)
	UpdateAsset(roomNumber int, assetID string, newSerialNumber string, condition string) (*model.HostelAsset, error)
	SeedDefaultRooms()
}

// MessServiceInterface abstracts meal timetables and food ratings
type MessServiceInterface interface {
	SeedDefaultMenuAndReviews()
	GetWeeklyTimetable() []model.MessMeal
	GetMealByID(id string) (*model.MessMeal, error)
	UpdateMeal(meal model.MessMeal) (*model.MessMeal, error)
	SubmitRating(req SubmitRatingRequest) (*model.MessRating, error)
	GetRatingsReport(mealID string, ratingFilter string) model.MessReportSummary
}

// ComplaintServiceInterface abstracts grievances and anonymity handling
type ComplaintServiceInterface interface {
	CreateComplaint(c model.Complaint) (*model.Complaint, error)
	GetComplaint(id, viewerID string) (*model.Complaint, error)
	ListComplaints(category, status, submittedBy, viewerID string, allowedCategories []string) []model.Complaint
	UpdateComplaintStatus(id, newStatus, remarks, resolvedBy string) (*model.Complaint, error)
	RaiseDispute(c model.Complaint) (*model.Complaint, error)
	ListDisputes(targetType, status, submittedBy, viewerID string, allowedCategories []string) []model.Complaint
}

// SessionalServiceInterface abstracts continuous internal evaluation, AKTU marks calculations, datesheets, and freeze audits
type SessionalServiceInterface interface {
	GetRecords(ctx context.Context, studentID, subjectCode string, semester int) ([]model.InternalAssessmentRecord, error)
	RecordMarks(ctx context.Context, req model.UpdateMarksRequest) (*model.InternalAssessmentRecord, error)
	FreezeMarks(ctx context.Context, req model.FreezeInternalMarksRequest) (*model.AKTUInternalAwardList, error)
	GetSchedules(ctx context.Context, semester int, examType string) ([]model.SessionalExamSchedule, error)
	GetSeatingLayout(ctx context.Context, hallNumber, examType string) ([]model.DeskSeatingAllocation, error)
	GetAwardList(ctx context.Context, subjectCode string, semester int) (*model.AKTUInternalAwardList, error)
}

// DigiLockerServiceInterface abstracts government credentials verification, OAuth 2.0 PKCE, and APAAR integration
type DigiLockerServiceInterface interface {
	GenerateAuthURL(ctx context.Context, req model.DigiLockerAuthURLRequest) (*model.DigiLockerAuthURLResponse, error)
	ExchangeAndSync(ctx context.Context, req model.DigiLockerExchangeRequest) (*model.StudentProfile, error)
	GetStatus(ctx context.Context, studentID string) (*model.DigiLockerStatusResponse, error)
	Disconnect(ctx context.Context, studentID string) (*model.StudentProfile, error)
}

// PaymentServiceInterface abstracts institutional fee gateway checkout, multi-provider routing, signature verification, and webhook settlement
type PaymentServiceInterface interface {
	GetPublicConfig(ctx context.Context) model.PaymentGatewayPublicConfig
	CreateOrder(ctx context.Context, req model.CreatePaymentOrderRequest) (*model.PaymentOrder, error)
	VerifyAndCapture(ctx context.Context, req model.VerifyPaymentRequest) (*model.FeePayment, *model.FeeReceipt, error)
	ProcessWebhook(ctx context.Context, rawPayload []byte, signature string) error
}

// Ensure concrete services satisfy interfaces at compile-time
var (
	_ PermissionServiceInterface = (*PermissionService)(nil)
	_ AcademicServiceInterface   = (*AcademicService)(nil)
	_ HostelServiceInterface     = (*HostelService)(nil)
	_ MessServiceInterface       = (*MessService)(nil)
	_ ComplaintServiceInterface  = (*ComplaintService)(nil)
	_ SessionalServiceInterface  = (*SessionalService)(nil)
	_ DigiLockerServiceInterface = (*DigiLockerService)(nil)
	_ PaymentServiceInterface    = (*PaymentService)(nil)
)
