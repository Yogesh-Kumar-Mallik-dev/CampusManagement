package facade

import (
	"context"
	"fmt"

	"campus/backend/internal/idgen"
	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

// CampusFacadeInterface defines the unified domain interface across the campus ecosystem
type CampusFacadeInterface interface {
	// Identity & Auth
	GenerateHandle(ctx context.Context, archetype, name string, year int, extra string) (string, error)
	AuthorizeUser(ctx context.Context, userID, permission, scope string) (bool, string)
	GetUserRoles(userID string) []model.UserRoleAssignment
	GetUserPermissions(userID string) []string
	AssignRole(ctx context.Context, userID, role, scope string) error

	// Academics
	GetCourses(ctx context.Context) ([]model.Course, error)
	GetTimetable(ctx context.Context, scope string) ([]model.TimetableSlot, error)
	CheckTimetableConflicts(ctx context.Context, slot model.TimetableSlot) ([]model.TimetableConflict, error)
	DeclareDayOff(ctx context.Context, req model.DayOffRequest) error
	RecordAttendance(ctx context.Context, markedBy string, batch model.OfflineAttendanceBatch) ([]model.AttendanceSession, error)
	GetStudentAttendance(ctx context.Context, studentID string) ([]model.AttendanceSummary, error)
	GetTargetedNotices(ctx context.Context, scopes []string) ([]model.Notice, error)
	PublishNotice(ctx context.Context, notice model.Notice) (model.Notice, error)
	ListDepartments(ctx context.Context) ([]model.Department, error)
	CreateDepartment(ctx context.Context, req model.CreateDepartmentRequest) (model.Department, error)

	// Residential & Hostel
	GetRooms() ([]model.HostelRoom, error)
	GetRoom(roomNumber int) (*model.HostelRoom, error)
	UpdateRoom(oldNum, newNum int, block string) (*model.HostelRoom, error)
	AddHostelAsset(roomNumber int, assetType, serialNumber, condition string) (*model.HostelAsset, error)
	UpdateHostelAsset(roomNumber int, assetID, serial, condition string) (*model.HostelAsset, error)
	AssignHostelOccupant(roomNumber int, userID, handle, name string) (*model.HostelOccupant, error)
	RemoveHostelOccupant(roomNumber int, identifier string) error

	// Dining & Mess
	GetWeeklyMessTimetable() []model.MessMeal
	GetMessMeal(id string) (*model.MessMeal, error)
	UpdateMessMeal(meal model.MessMeal) (*model.MessMeal, error)
	SubmitMealRating(req service.SubmitRatingRequest) (*model.MessRating, error)
	GetMessRatingsReport(mealID, filter string) model.MessReportSummary

	// Grievances, Complaints & Disputes
	CreateComplaint(c model.Complaint) (*model.Complaint, error)
	GetComplaint(id, viewerID string) (*model.Complaint, error)
	ListComplaints(category, status, submittedBy, viewerID string, allowedCategories []string) []model.Complaint
	UpdateComplaintStatus(id, newStatus, remarks, resolvedBy string) (*model.Complaint, error)
	RaiseDispute(c model.Complaint) (*model.Complaint, error)
	ListDisputes(targetType, status, submittedBy, viewerID string, allowedCategories []string) []model.Complaint

	// Fees & Fines
	GetFeeSummary(ctx context.Context, studentID string) (model.FeeSummary, error)
	GetInvoices(ctx context.Context, studentID, status string) ([]model.FeeInvoice, error)
	GetInvoiceByID(ctx context.Context, id string) (*model.FeeInvoice, error)
	PayInvoice(ctx context.Context, req model.PayInvoiceRequest) (*model.FeePayment, *model.FeeReceipt, error)
	GetFines(ctx context.Context, studentID, status string) ([]model.FineRecord, error)
	PayFine(ctx context.Context, req model.PayFineRequest) (*model.FeePayment, *model.FeeReceipt, error)
	AppealFine(ctx context.Context, fineID, reason string) (*model.FineRecord, error)
	WaiveFine(ctx context.Context, fineID, waivedBy string) (*model.FineRecord, error)
	GetPaymentRecords(ctx context.Context, studentID string) ([]model.FeePayment, error)
	GetReceipt(ctx context.Context, receiptNumber string) (*model.FeeReceipt, error)
	DownloadInvoicePDF(ctx context.Context, invoiceID string) ([]byte, string, error)

	// Library
	GetLibrarySummary(ctx context.Context, studentID string) (model.LibrarySummary, error)
	GetPhysicalBooks(ctx context.Context, query, category string) ([]model.PhysicalBook, error)
	GetBookByID(ctx context.Context, id string) (*model.PhysicalBook, error)
	GetBorrowRecords(ctx context.Context, studentID, status string) ([]model.BorrowRecord, error)
	BorrowBook(ctx context.Context, req model.BorrowBookRequest) (*model.BorrowRecord, error)
	ReturnBook(ctx context.Context, req model.ReturnBookRequest) (*model.BorrowRecord, error)
	RenewBook(ctx context.Context, req model.RenewBookRequest) (*model.BorrowRecord, error)
	GetEBooks(ctx context.Context, query, category string) ([]model.EBook, error)
}

// CampusFacade coordinates operations across all backend domain services through a single entry point
type CampusFacade struct {
	idGen       idgen.IDServiceInterface
	permService service.PermissionServiceInterface
	academic    service.AcademicServiceInterface
	hostel      service.HostelServiceInterface
	mess        service.MessServiceInterface
	complaints  service.ComplaintServiceInterface
	fee         service.FeeServiceInterface
	library     service.LibraryServiceInterface
}

func NewCampusFacade(
	idGen idgen.IDServiceInterface,
	permService service.PermissionServiceInterface,
	academic service.AcademicServiceInterface,
	hostel service.HostelServiceInterface,
	mess service.MessServiceInterface,
	complaints service.ComplaintServiceInterface,
	fee service.FeeServiceInterface,
	library service.LibraryServiceInterface,
) *CampusFacade {
	return &CampusFacade{
		idGen:       idGen,
		permService: permService,
		academic:    academic,
		hostel:      hostel,
		mess:        mess,
		complaints:  complaints,
		fee:         fee,
		library:     library,
	}
}

var _ CampusFacadeInterface = (*CampusFacade)(nil)

// Identity & Authorization
func (f *CampusFacade) GenerateHandle(ctx context.Context, archetype, name string, year int, extra string) (string, error) {
	if f.idGen == nil {
		return "", fmt.Errorf("id generator service unavailable")
	}
	switch archetype {
	case "student":
		return f.idGen.NextStudentID(ctx, name, year, "regular", extra)
	case "employee":
		return f.idGen.NextEmployeeID(ctx, name, year)
	case "faculty":
		return f.idGen.NextFacultyID(ctx, name, year)
	case "staff":
		return f.idGen.NextStaffID(ctx, name, year)
	case "contractor", "external":
		return f.idGen.NextExternalID(ctx, name, year)
	default:
		return f.idGen.NextExternalID(ctx, name, year)
	}
}

func (f *CampusFacade) AuthorizeUser(ctx context.Context, userID, permission, scope string) (bool, string) {
	if f.permService == nil {
		return false, "authorization service unavailable"
	}
	return f.permService.Can(ctx, userID, permission, scope)
}

func (f *CampusFacade) GetUserRoles(userID string) []model.UserRoleAssignment {
	if f.permService == nil {
		return nil
	}
	return f.permService.GetUserRoles(userID)
}

func (f *CampusFacade) GetUserPermissions(userID string) []string {
	if f.permService == nil {
		return nil
	}
	return f.permService.GetUserPermissions(userID)
}

func (f *CampusFacade) AssignRole(ctx context.Context, userID, role, scope string) error {
	if f.permService == nil {
		return fmt.Errorf("permission service unavailable")
	}
	return f.permService.AssignRole(ctx, userID, role, scope, nil)
}

// Academics
func (f *CampusFacade) GetCourses(ctx context.Context) ([]model.Course, error) {
	if f.academic == nil {
		return nil, fmt.Errorf("academic service unavailable")
	}
	return f.academic.ListCourses(ctx)
}

func (f *CampusFacade) GetTimetable(ctx context.Context, scope string) ([]model.TimetableSlot, error) {
	if f.academic == nil {
		return nil, fmt.Errorf("academic service unavailable")
	}
	return f.academic.GetTimetableForScope(ctx, scope)
}

func (f *CampusFacade) CheckTimetableConflicts(ctx context.Context, slot model.TimetableSlot) ([]model.TimetableConflict, error) {
	if f.academic == nil {
		return nil, fmt.Errorf("academic service unavailable")
	}
	return f.academic.CheckTimetableConflicts(ctx, slot)
}

func (f *CampusFacade) DeclareDayOff(ctx context.Context, req model.DayOffRequest) error {
	if f.academic == nil {
		return fmt.Errorf("academic service unavailable")
	}
	return f.academic.DeclareDayOff(ctx, req)
}

func (f *CampusFacade) RecordAttendance(ctx context.Context, markedBy string, batch model.OfflineAttendanceBatch) ([]model.AttendanceSession, error) {
	if f.academic == nil {
		return nil, fmt.Errorf("academic service unavailable")
	}
	return f.academic.SyncAttendanceBatch(ctx, markedBy, batch)
}

func (f *CampusFacade) GetStudentAttendance(ctx context.Context, studentID string) ([]model.AttendanceSummary, error) {
	if f.academic == nil {
		return nil, fmt.Errorf("academic service unavailable")
	}
	return f.academic.GetStudentAttendanceSummary(ctx, studentID)
}

func (f *CampusFacade) GetTargetedNotices(ctx context.Context, scopes []string) ([]model.Notice, error) {
	if f.academic == nil {
		return nil, fmt.Errorf("academic service unavailable")
	}
	return f.academic.GetTargetedNotices(ctx, scopes)
}

func (f *CampusFacade) PublishNotice(ctx context.Context, notice model.Notice) (model.Notice, error) {
	if f.academic == nil {
		return model.Notice{}, fmt.Errorf("academic service unavailable")
	}
	return f.academic.PublishNotice(ctx, notice)
}

func (f *CampusFacade) ListDepartments(ctx context.Context) ([]model.Department, error) {
	if f.academic == nil {
		return nil, fmt.Errorf("academic service unavailable")
	}
	return f.academic.ListDepartments(ctx)
}

func (f *CampusFacade) CreateDepartment(ctx context.Context, req model.CreateDepartmentRequest) (model.Department, error) {
	if f.academic == nil {
		return model.Department{}, fmt.Errorf("academic service unavailable")
	}
	return f.academic.CreateDepartment(ctx, req)
}

// Residential & Hostel
func (f *CampusFacade) GetRooms() ([]model.HostelRoom, error) {
	if f.hostel == nil {
		return nil, fmt.Errorf("hostel service unavailable")
	}
	return f.hostel.GetRooms()
}

func (f *CampusFacade) GetRoom(roomNumber int) (*model.HostelRoom, error) {
	if f.hostel == nil {
		return nil, fmt.Errorf("hostel service unavailable")
	}
	return f.hostel.GetRoomByNumber(roomNumber)
}

func (f *CampusFacade) UpdateRoom(oldNum, newNum int, block string) (*model.HostelRoom, error) {
	if f.hostel == nil {
		return nil, fmt.Errorf("hostel service unavailable")
	}
	return f.hostel.UpdateRoom(oldNum, newNum, block)
}

func (f *CampusFacade) AddHostelAsset(roomNumber int, assetType, serialNumber, condition string) (*model.HostelAsset, error) {
	if f.hostel == nil {
		return nil, fmt.Errorf("hostel service unavailable")
	}
	return f.hostel.AddAsset(roomNumber, assetType, serialNumber, condition)
}

func (f *CampusFacade) UpdateHostelAsset(roomNumber int, assetID, serial, condition string) (*model.HostelAsset, error) {
	if f.hostel == nil {
		return nil, fmt.Errorf("hostel service unavailable")
	}
	return f.hostel.UpdateAsset(roomNumber, assetID, serial, condition)
}

func (f *CampusFacade) AssignHostelOccupant(roomNumber int, userID, handle, name string) (*model.HostelOccupant, error) {
	if f.hostel == nil {
		return nil, fmt.Errorf("hostel service unavailable")
	}
	return f.hostel.AssignOccupant(roomNumber, userID, handle, name)
}

func (f *CampusFacade) RemoveHostelOccupant(roomNumber int, identifier string) error {
	if f.hostel == nil {
		return fmt.Errorf("hostel service unavailable")
	}
	return f.hostel.RemoveOccupant(roomNumber, identifier)
}

// Dining & Mess
func (f *CampusFacade) GetWeeklyMessTimetable() []model.MessMeal {
	if f.mess == nil {
		return nil
	}
	return f.mess.GetWeeklyTimetable()
}

func (f *CampusFacade) GetMessMeal(id string) (*model.MessMeal, error) {
	if f.mess == nil {
		return nil, fmt.Errorf("mess service unavailable")
	}
	return f.mess.GetMealByID(id)
}

func (f *CampusFacade) UpdateMessMeal(meal model.MessMeal) (*model.MessMeal, error) {
	if f.mess == nil {
		return nil, fmt.Errorf("mess service unavailable")
	}
	return f.mess.UpdateMeal(meal)
}

func (f *CampusFacade) SubmitMealRating(req service.SubmitRatingRequest) (*model.MessRating, error) {
	if f.mess == nil {
		return nil, fmt.Errorf("mess service unavailable")
	}
	return f.mess.SubmitRating(req)
}

func (f *CampusFacade) GetMessRatingsReport(mealID, filter string) model.MessReportSummary {
	if f.mess == nil {
		return model.MessReportSummary{}
	}
	return f.mess.GetRatingsReport(mealID, filter)
}

// Grievances & Complaints
func (f *CampusFacade) CreateComplaint(c model.Complaint) (*model.Complaint, error) {
	if f.complaints == nil {
		return nil, fmt.Errorf("complaints service unavailable")
	}
	return f.complaints.CreateComplaint(c)
}

func (f *CampusFacade) GetComplaint(id, viewerID string) (*model.Complaint, error) {
	if f.complaints == nil {
		return nil, fmt.Errorf("complaints service unavailable")
	}
	return f.complaints.GetComplaint(id, viewerID)
}

func (f *CampusFacade) ListComplaints(category, status, submittedBy, viewerID string, allowedCategories []string) []model.Complaint {
	if f.complaints == nil {
		return nil
	}
	return f.complaints.ListComplaints(category, status, submittedBy, viewerID, allowedCategories)
}

func (f *CampusFacade) UpdateComplaintStatus(id, newStatus, remarks, resolvedBy string) (*model.Complaint, error) {
	if f.complaints == nil {
		return nil, fmt.Errorf("complaints service unavailable")
	}
	return f.complaints.UpdateComplaintStatus(id, newStatus, remarks, resolvedBy)
}

func (f *CampusFacade) RaiseDispute(c model.Complaint) (*model.Complaint, error) {
	if f.complaints == nil {
		return nil, fmt.Errorf("complaints service unavailable")
	}
	return f.complaints.RaiseDispute(c)
}

func (f *CampusFacade) ListDisputes(targetType, status, submittedBy, viewerID string, allowedCategories []string) []model.Complaint {
	if f.complaints == nil {
		return nil
	}
	return f.complaints.ListDisputes(targetType, status, submittedBy, viewerID, allowedCategories)
}

// Fees & Fines
func (f *CampusFacade) GetFeeSummary(ctx context.Context, studentID string) (model.FeeSummary, error) {
	if f.fee == nil {
		return model.FeeSummary{}, fmt.Errorf("fee service unavailable")
	}
	return f.fee.GetFeeSummary(ctx, studentID)
}

func (f *CampusFacade) GetInvoices(ctx context.Context, studentID, status string) ([]model.FeeInvoice, error) {
	if f.fee == nil {
		return nil, fmt.Errorf("fee service unavailable")
	}
	return f.fee.GetInvoices(ctx, studentID, status)
}

func (f *CampusFacade) GetInvoiceByID(ctx context.Context, id string) (*model.FeeInvoice, error) {
	if f.fee == nil {
		return nil, fmt.Errorf("fee service unavailable")
	}
	return f.fee.GetInvoiceByID(ctx, id)
}

func (f *CampusFacade) PayInvoice(ctx context.Context, req model.PayInvoiceRequest) (*model.FeePayment, *model.FeeReceipt, error) {
	if f.fee == nil {
		return nil, nil, fmt.Errorf("fee service unavailable")
	}
	return f.fee.PayInvoice(ctx, req)
}

func (f *CampusFacade) GetFines(ctx context.Context, studentID, status string) ([]model.FineRecord, error) {
	if f.fee == nil {
		return nil, fmt.Errorf("fee service unavailable")
	}
	return f.fee.GetFines(ctx, studentID, status)
}

func (f *CampusFacade) PayFine(ctx context.Context, req model.PayFineRequest) (*model.FeePayment, *model.FeeReceipt, error) {
	if f.fee == nil {
		return nil, nil, fmt.Errorf("fee service unavailable")
	}
	return f.fee.PayFine(ctx, req)
}

func (f *CampusFacade) AppealFine(ctx context.Context, fineID, reason string) (*model.FineRecord, error) {
	if f.fee == nil {
		return nil, fmt.Errorf("fee service unavailable")
	}
	return f.fee.AppealFine(ctx, fineID, reason)
}

func (f *CampusFacade) WaiveFine(ctx context.Context, fineID, waivedBy string) (*model.FineRecord, error) {
	if f.fee == nil {
		return nil, fmt.Errorf("fee service unavailable")
	}
	return f.fee.WaiveFine(ctx, fineID, waivedBy)
}

func (f *CampusFacade) GetPaymentRecords(ctx context.Context, studentID string) ([]model.FeePayment, error) {
	if f.fee == nil {
		return nil, fmt.Errorf("fee service unavailable")
	}
	return f.fee.GetPaymentRecords(ctx, studentID)
}

func (f *CampusFacade) GetReceipt(ctx context.Context, receiptNumber string) (*model.FeeReceipt, error) {
	if f.fee == nil {
		return nil, fmt.Errorf("fee service unavailable")
	}
	return f.fee.GetReceipt(ctx, receiptNumber)
}

func (f *CampusFacade) DownloadInvoicePDF(ctx context.Context, invoiceID string) ([]byte, string, error) {
	if f.fee == nil {
		return nil, "", fmt.Errorf("fee service unavailable")
	}
	return f.fee.GenerateInvoicePDF(ctx, invoiceID)
}

func (f *CampusFacade) GetLibrarySummary(ctx context.Context, studentID string) (model.LibrarySummary, error) {
	if f.library == nil {
		return model.LibrarySummary{}, fmt.Errorf("library service unavailable")
	}
	return f.library.GetLibrarySummary(ctx, studentID)
}

func (f *CampusFacade) GetPhysicalBooks(ctx context.Context, query, category string) ([]model.PhysicalBook, error) {
	if f.library == nil {
		return nil, fmt.Errorf("library service unavailable")
	}
	return f.library.GetPhysicalBooks(ctx, query, category)
}

func (f *CampusFacade) GetBookByID(ctx context.Context, id string) (*model.PhysicalBook, error) {
	if f.library == nil {
		return nil, fmt.Errorf("library service unavailable")
	}
	return f.library.GetBookByID(ctx, id)
}

func (f *CampusFacade) GetBorrowRecords(ctx context.Context, studentID, status string) ([]model.BorrowRecord, error) {
	if f.library == nil {
		return nil, fmt.Errorf("library service unavailable")
	}
	return f.library.GetBorrowRecords(ctx, studentID, status)
}

func (f *CampusFacade) BorrowBook(ctx context.Context, req model.BorrowBookRequest) (*model.BorrowRecord, error) {
	if f.library == nil {
		return nil, fmt.Errorf("library service unavailable")
	}
	return f.library.BorrowBook(ctx, req)
}

func (f *CampusFacade) ReturnBook(ctx context.Context, req model.ReturnBookRequest) (*model.BorrowRecord, error) {
	if f.library == nil {
		return nil, fmt.Errorf("library service unavailable")
	}
	return f.library.ReturnBook(ctx, req)
}

func (f *CampusFacade) RenewBook(ctx context.Context, req model.RenewBookRequest) (*model.BorrowRecord, error) {
	if f.library == nil {
		return nil, fmt.Errorf("library service unavailable")
	}
	return f.library.RenewBook(ctx, req)
}

func (f *CampusFacade) GetEBooks(ctx context.Context, query, category string) ([]model.EBook, error) {
	if f.library == nil {
		return nil, fmt.Errorf("library service unavailable")
	}
	return f.library.GetEBooks(ctx, query, category)
}

