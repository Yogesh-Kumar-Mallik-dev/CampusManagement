package facade

import (
	"context"
	"testing"

	"campus/backend/internal/cache"
	"campus/backend/internal/idgen"
	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

func TestCampusFacadeFullLifecycle(t *testing.T) {
	ctx := context.Background()
	store := cache.NewMemoryStore()
	cacheManager := cache.NewResilientManager(store)

	idService := idgen.NewIDService(nil)
	permService := service.NewPermissionService(nil, cacheManager)
	academicService := service.NewAcademicService(nil, cacheManager, permService)
	hostelService := service.NewHostelService(nil, permService)
	messService := service.NewMessService(nil, permService)
	complaintService := service.NewComplaintService()
	feeService := service.NewFeeService(nil, permService)
	libraryService := service.NewLibraryService(nil, feeService)

	// Seed data
	hostelService.SeedDefaultRooms()
	messService.SeedDefaultMenuAndReviews()

	facade := NewCampusFacade(
		idService,
		permService,
		academicService,
		hostelService,
		messService,
		complaintService,
		feeService,
		libraryService,
	)

	// 1. Identity & Auth via Facade
	handle, err := facade.GenerateHandle(ctx, "student", "Harish", 2025, "btech")
	if err != nil || handle == "" {
		t.Fatalf("failed to generate handle: %v", err)
	}

	empHandle, err := facade.GenerateHandle(ctx, "employee", "Priya", 2024, "")
	if err != nil || empHandle == "" {
		t.Fatalf("failed to generate employee handle: %v", err)
	}

	facHandle, _ := facade.GenerateHandle(ctx, "faculty", "Priya", 2024, "")
	staffHandle, _ := facade.GenerateHandle(ctx, "staff", "Ramesh", 2023, "")
	extHandle, _ := facade.GenerateHandle(ctx, "contractor", "Mukesh", 2025, "")
	if facHandle == "" || staffHandle == "" || extHandle == "" {
		t.Fatal("expected non-empty handles")
	}

	err = facade.AssignRole(ctx, "user-1", "student", "global")
	if err != nil {
		t.Fatalf("assign role failed: %v", err)
	}

	roles := facade.GetUserRoles("user-1")
	if len(roles) == 0 {
		t.Fatal("expected assigned roles")
	}

	perms := facade.GetUserPermissions("user-1")
	_ = perms

	canAccess, _ := facade.AuthorizeUser(ctx, "user-1", "timetable:view", "global")
	_ = canAccess

	// 2. Academics via Facade
	dept, err := facade.CreateDepartment(ctx, model.CreateDepartmentRequest{
		Code: "CSE",
		Name: "Computer Science & Engineering",
	})
	if err != nil || dept.Code != "CSE" {
		t.Fatalf("failed to create department: %v", err)
	}

	depts, err := facade.ListDepartments(ctx)
	if err != nil || len(depts) == 0 {
		t.Fatalf("failed to list departments: %v", err)
	}

	courses, err := facade.GetCourses(ctx)
	if err != nil {
		t.Fatalf("failed to get courses: %v", err)
	}
	_ = courses

	timetable, err := facade.GetTimetable(ctx, "global")
	if err != nil {
		t.Fatalf("failed to get timetable: %v", err)
	}
	_ = timetable

	slot := model.TimetableSlot{
		CourseCode: "CS101",
		DayOfWeek:  1,
		StartTime:  "09:00",
		EndTime:    "10:00",
		RoomNumber: "LH-101",
		ScopeCode:  "sec:cse-1a",
	}
	conflicts, err := facade.CheckTimetableConflicts(ctx, slot)
	if err != nil {
		t.Fatalf("check conflicts failed: %v", err)
	}
	_ = conflicts

	err = facade.DeclareDayOff(ctx, model.DayOffRequest{
		DayOfWeek: 1,
		ScopeCode: "sec:cse-1a",
		Reason:    "Campus Event",
	})
	if err != nil {
		t.Fatalf("declare day off failed: %v", err)
	}

	notice, err := facade.PublishNotice(ctx, model.Notice{
		Title:           "Holiday Notice",
		Content:         "Campus will remain closed on Friday.",
		TargetScopeCode: "global",
	})
	if err != nil || notice.Title != "Holiday Notice" {
		t.Fatalf("publish notice failed: %v", err)
	}

	notices, err := facade.GetTargetedNotices(ctx, []string{"global"})
	if err != nil || len(notices) == 0 {
		t.Fatalf("get notices failed: %v", err)
	}

	batch := model.OfflineAttendanceBatch{
		Sessions: []model.AttendanceSession{
			{
				CourseCode:     "CS101",
				SessionDate:    "2026-11-09",
				ScopeCode:      "global",
				MarkedByUserID: "teacher-1",
				Records: []model.AttendanceRecord{
					{StudentID: "student-1", Status: model.StatusPresent},
				},
			},
		},
	}
	sessions, err := facade.RecordAttendance(ctx, "teacher-1", batch)
	if err != nil || len(sessions) == 0 {
		t.Fatalf("record attendance failed: %v", err)
	}

	summary, err := facade.GetStudentAttendance(ctx, "student-1")
	if err != nil {
		t.Fatalf("get student attendance failed: %v", err)
	}
	_ = summary

	// 3. Residential & Hostel via Facade
	rooms, err := facade.GetRooms()
	if err != nil || len(rooms) == 0 {
		t.Fatalf("get rooms failed: %v", err)
	}

	room, err := facade.GetRoom(101)
	if err != nil || room == nil {
		t.Fatalf("get room 101 failed: %v", err)
	}

	_, err = hostelService.CreateRoom(199, "New Block")
	if err != nil {
		t.Fatalf("create room failed: %v", err)
	}

	asset, err := facade.AddHostelAsset(199, "fan", "FAN-199-01", "good")
	if err != nil || asset == nil {
		t.Fatalf("add hostel asset failed: %v", err)
	}

	updatedAsset, err := facade.UpdateHostelAsset(199, asset.ID, "FAN-199-01-REV", "good")
	if err != nil || updatedAsset.SerialNumber != "FAN-199-01-REV" {
		t.Fatalf("update asset failed: %v", err)
	}

	occ, err := facade.AssignHostelOccupant(199, "std-99", "harish_2025", "Harish K")
	if err != nil || occ == nil {
		t.Fatalf("assign occupant failed: %v", err)
	}

	err = facade.RemoveHostelOccupant(199, "std-99")
	if err != nil {
		t.Fatalf("remove occupant failed: %v", err)
	}

	updatedRoom, err := facade.UpdateRoom(199, 199, "Updated Aryabhatta Block")
	if err != nil || updatedRoom.BlockName != "Updated Aryabhatta Block" {
		t.Fatalf("update room failed: %v", err)
	}

	// 4. Dining & Mess via Facade
	messTimetable := facade.GetWeeklyMessTimetable()
	if len(messTimetable) == 0 {
		t.Fatal("expected weekly mess timetable")
	}

	firstMeal := messTimetable[0]
	meal, err := facade.GetMessMeal(firstMeal.ID)
	if err != nil || meal == nil {
		t.Fatalf("get meal failed: %v", err)
	}

	meal.MenuSummary = "Updated Paneer Masala, Rice, Salad"
	upMeal, err := facade.UpdateMessMeal(*meal)
	if err != nil || upMeal.MenuSummary != meal.MenuSummary {
		t.Fatalf("update meal failed: %v", err)
	}

	rating, err := facade.SubmitMealRating(service.SubmitRatingRequest{
		MealID:       firstMeal.ID,
		UserID:       "std-1",
		UserName:     "Harish K",
		CampusHandle: "harish_2025",
		Rating:       model.RatingGood,
		Message:      "Good quality meal",
	})
	if err != nil || rating == nil {
		t.Fatalf("submit rating failed: %v", err)
	}

	report := facade.GetMessRatingsReport(firstMeal.ID, "all")
	if report.TotalRatings == 0 {
		t.Fatal("expected rating reports")
	}

	// 5. Grievances & Complaints via Facade
	complaint, err := facade.CreateComplaint(model.Complaint{
		Category:    model.ComplaintCategoryHostel,
		Title:       "Water cooler leakage",
		Description: "Second floor water cooler is leaking continuously.",
		Urgency:     "medium",
		IsAnonymous: false,
		SubmittedBy: "harish_2025_l_btech_1",
	})
	if err != nil || complaint == nil {
		t.Fatalf("create complaint failed: %v", err)
	}

	complaintsList := facade.ListComplaints("hostel", "", "", "", nil)
	if len(complaintsList) == 0 {
		t.Fatal("expected complaints list")
	}

	viewedComp, err := facade.GetComplaint(complaint.ID, "harish_2025_l_btech_1")
	if err != nil || viewedComp == nil {
		t.Fatalf("get complaint failed: %v", err)
	}

	updatedComp, err := facade.UpdateComplaintStatus(complaint.ID, model.ComplaintStatusInProgress, "Maintenance dispatched", "admin")
	if err != nil || updatedComp.Status != model.ComplaintStatusInProgress {
		t.Fatalf("update complaint status failed: %v", err)
	}

	// 5.b Disputes via Facade
	dispute, err := facade.RaiseDispute(model.Complaint{
		Title:               "Dispute on semester fee invoice",
		Description:         "Duplicate computing fee charged.",
		Category:            model.ComplaintCategoryStudent,
		Urgency:             model.ComplaintUrgencyHigh,
		IsAnonymous:         false,
		SubmittedBy:         "usr-harish_2025_l_btech_1",
		SubmitterName:       "Harish Kumar",
		SubmitterHandle:     "harish_2025_l_btech_1",
		SubmitterRole:       "student",
		DisputeTargetType:   model.DisputeTargetFee,
		DisputeTargetID:     "INV-2026-001",
		DisputeEvidence:     "Receipt reference and itemized invoice code.",
		RequestedResolution: "Fee Adjustment",
	})
	if err != nil || !dispute.IsDispute {
		t.Fatalf("raise dispute failed: %v", err)
	}

	disputesList := facade.ListDisputes("fee", "", "", "", nil)
	if len(disputesList) == 0 {
		t.Fatal("expected non-empty disputes list")
	}

	// 5. Fees & Fines via Facade
	feeSummary, err := facade.GetFeeSummary(ctx, "usr-harish_2025_l_btech_1")
	if err != nil || feeSummary.TotalDues <= 0 {
		t.Fatalf("get fee summary failed: %v", err)
	}

	invoices, err := facade.GetInvoices(ctx, "usr-harish_2025_l_btech_1", "")
	if err != nil || len(invoices) == 0 {
		t.Fatalf("get invoices failed: %v", err)
	}

	var targetInv model.FeeInvoice
	for _, inv := range invoices {
		if inv.DueAmount > 0 {
			targetInv = inv
			break
		}
	}
	if targetInv.ID == "" {
		t.Fatal("expected at least one invoice with due balance")
	}

	singleInv, err := facade.GetInvoiceByID(ctx, targetInv.ID)
	if err != nil || singleInv == nil {
		t.Fatalf("get invoice by id failed: %v", err)
	}

	payInv, rec, err := facade.PayInvoice(ctx, model.PayInvoiceRequest{
		InvoiceID:     targetInv.ID,
		StudentID:     targetInv.StudentID,
		Amount:        1000.0,
		PaymentMethod: "upi",
	})
	if err != nil || payInv == nil || rec == nil {
		t.Fatalf("pay invoice failed: %v", err)
	}

	fines, err := facade.GetFines(ctx, "usr-harish_2025_l_btech_1", "")
	if err != nil || len(fines) == 0 {
		t.Fatalf("get fines failed: %v", err)
	}

	appealedFine, err := facade.AppealFine(ctx, fines[0].ID, "Valid medical reason")
	if err != nil || appealedFine.Status != model.FineStatusAppealed {
		t.Fatalf("appeal fine failed: %v", err)
	}

	waivedFine, err := facade.WaiveFine(ctx, fines[0].ID, "admin")
	if err != nil || waivedFine.Status != model.FineStatusWaived {
		t.Fatalf("waive fine failed: %v", err)
	}

	// Pay an unpaid fine
	var unpaidFine model.FineRecord
	for _, f := range fines {
		if f.Status == model.FineStatusUnpaid {
			unpaidFine = f
			break
		}
	}
	if unpaidFine.ID != "" {
		payFine, fineRec, err := facade.PayFine(ctx, model.PayFineRequest{
			FineID:        unpaidFine.ID,
			StudentID:     unpaidFine.StudentID,
			PaymentMethod: "netbanking",
		})
		if err != nil || payFine == nil || fineRec == nil {
			t.Fatalf("pay fine failed: %v", err)
		}
	}

	paymentRecords, err := facade.GetPaymentRecords(ctx, "usr-harish_2025_l_btech_1")
	if err != nil || len(paymentRecords) == 0 {
		t.Fatalf("get payment records failed: %v", err)
	}

	fetchedReceipt, err := facade.GetReceipt(ctx, rec.ReceiptNumber)
	if err != nil || fetchedReceipt == nil {
		t.Fatalf("get receipt failed: %v", err)
	}

	pdfBytes, filename, err := facade.DownloadInvoicePDF(ctx, targetInv.ID)
	if err != nil || len(pdfBytes) == 0 || filename == "" {
		t.Fatalf("download invoice pdf failed: %v", err)
	}

	// 7. Library Management via Facade
	studentID := "usr-harish_2025_l_btech_1"
	libSummary, err := facade.GetLibrarySummary(ctx, studentID)
	if err != nil {
		t.Fatalf("get library summary failed: %v", err)
	}
	if libSummary.MaxBorrowQuota != 4 {
		t.Fatalf("expected max quota 4, got %d", libSummary.MaxBorrowQuota)
	}

	books, err := facade.GetPhysicalBooks(ctx, "", "")
	if err != nil || len(books) == 0 {
		t.Fatalf("get physical books failed: %v", err)
	}

	singleBook, err := facade.GetBookByID(ctx, books[0].ID)
	if err != nil || singleBook == nil {
		t.Fatalf("get book by id failed: %v", err)
	}

	borrows, err := facade.GetBorrowRecords(ctx, studentID, "")
	if err != nil || len(borrows) == 0 {
		t.Fatalf("get borrow records failed: %v", err)
	}

	// First return the overdue loan directly as in-charge so the student is eligible to borrow again
	returnedOverdue, err := facade.ReturnBook(ctx, model.ReturnBookRequest{
		BorrowID:       "brw-os-01",
		StudentID:      studentID,
		ApprovedBy:     "usr-librarian-01",
		ApprovedByName: "Dr. Anita Sharma",
	})
	if err != nil || returnedOverdue.Status != model.BorrowStatusReturned {
		t.Fatalf("return overdue book failed: %v", err)
	}

	var bookToBorrow *model.PhysicalBook
	for i := range books {
		if books[i].AvailableCopies > 0 {
			bookToBorrow = &books[i]
			break
		}
	}
	if bookToBorrow == nil {
		t.Fatal("expected at least one available book in seed data")
	}

	borrowReq := model.BorrowBookRequest{
		StudentID: studentID,
		BookID:    bookToBorrow.ID,
	}
	newBorrow, err := facade.BorrowBook(ctx, borrowReq)
	if err != nil {
		t.Fatalf("borrow book failed: %v", err)
	}

	approvedBorrow, err := facade.ApproveBorrow(ctx, model.ApproveBorrowRequest{
		BorrowID:       newBorrow.ID,
		ApprovedBy:     "usr-librarian-01",
		ApprovedByName: "Dr. Anita Sharma",
	})
	if err != nil || approvedBorrow.Status != model.BorrowStatusActive {
		t.Fatalf("approve borrow failed: %v", err)
	}

	// Student requests renewal -> pending_renewal
	renewReq, err := facade.RenewBook(ctx, model.RenewBookRequest{
		BorrowID:  newBorrow.ID,
		StudentID: studentID,
	})
	if err != nil || renewReq.Status != model.BorrowStatusPendingRenewal {
		t.Fatalf("expected pending_renewal status: %v", err)
	}

	// In-Charge approves renewal
	renewedBorrow, err := facade.ApproveRenewal(ctx, model.ApproveRenewalRequest{
		BorrowID:       newBorrow.ID,
		ApprovedBy:     "usr-librarian-01",
		ApprovedByName: "Dr. Anita Sharma",
	})
	if err != nil || renewedBorrow.RenewalCount != 1 || renewedBorrow.Status != model.BorrowStatusActive {
		t.Fatalf("approve renewal failed: %v", err)
	}

	// Student requests return -> pending_return
	returnReq, err := facade.ReturnBook(ctx, model.ReturnBookRequest{
		BorrowID:  newBorrow.ID,
		StudentID: studentID,
	})
	if err != nil || returnReq.Status != model.BorrowStatusPendingReturn {
		t.Fatalf("expected pending_return status: %v", err)
	}

	// In-Charge verifies physical copy and approves return
	returnedBorrow, err := facade.ApproveReturn(ctx, model.ApproveReturnRequest{
		BorrowID:       newBorrow.ID,
		ApprovedBy:     "usr-librarian-01",
		ApprovedByName: "Dr. Anita Sharma",
	})
	if err != nil || returnedBorrow.Status != model.BorrowStatusReturned {
		t.Fatalf("approve return failed: %v", err)
	}

	ebooks, err := facade.GetEBooks(ctx, "", "")
	if err != nil || len(ebooks) == 0 {
		t.Fatalf("get ebooks failed: %v", err)
	}
}

func TestCampusFacadeNilSafety(t *testing.T) {
	ctx := context.Background()
	// Nil dependencies facade
	facade := NewCampusFacade(nil, nil, nil, nil, nil, nil, nil, nil)

	if _, err := facade.GenerateHandle(ctx, "student", "a", 2025, ""); err == nil {
		t.Fatal("expected error on nil idGen")
	}
	if allowed, _ := facade.AuthorizeUser(ctx, "u", "p", "s"); allowed {
		t.Fatal("expected false on nil permService")
	}
	if roles := facade.GetUserRoles("u"); roles != nil {
		t.Fatal("expected nil roles")
	}
	if perms := facade.GetUserPermissions("u"); perms != nil {
		t.Fatal("expected nil permissions")
	}
	if err := facade.AssignRole(ctx, "u", "r", "s"); err == nil {
		t.Fatal("expected error on nil permService")
	}
	if _, err := facade.GetCourses(ctx); err == nil {
		t.Fatal("expected error on nil academic")
	}
	if _, err := facade.GetTimetable(ctx, "g"); err == nil {
		t.Fatal("expected error on nil academic")
	}
	if _, err := facade.CheckTimetableConflicts(ctx, model.TimetableSlot{}); err == nil {
		t.Fatal("expected error on nil academic")
	}
	if err := facade.DeclareDayOff(ctx, model.DayOffRequest{}); err == nil {
		t.Fatal("expected error on nil academic")
	}
	if _, err := facade.RecordAttendance(ctx, "m", model.OfflineAttendanceBatch{}); err == nil {
		t.Fatal("expected error on nil academic")
	}
	if _, err := facade.GetStudentAttendance(ctx, "s"); err == nil {
		t.Fatal("expected error on nil academic")
	}
	if _, err := facade.GetTargetedNotices(ctx, nil); err == nil {
		t.Fatal("expected error on nil academic")
	}
	if _, err := facade.PublishNotice(ctx, model.Notice{}); err == nil {
		t.Fatal("expected error on nil academic")
	}
	if _, err := facade.ListDepartments(ctx); err == nil {
		t.Fatal("expected error on nil academic")
	}
	if _, err := facade.CreateDepartment(ctx, model.CreateDepartmentRequest{}); err == nil {
		t.Fatal("expected error on nil academic")
	}
	if _, err := facade.GetRooms(); err == nil {
		t.Fatal("expected error on nil hostel")
	}
	if _, err := facade.GetRoom(101); err == nil {
		t.Fatal("expected error on nil hostel")
	}
	if _, err := facade.UpdateRoom(101, 102, "b"); err == nil {
		t.Fatal("expected error on nil hostel")
	}
	if _, err := facade.AddHostelAsset(101, "fan", "s", "good"); err == nil {
		t.Fatal("expected error on nil hostel")
	}
	if _, err := facade.UpdateHostelAsset(101, "a", "s", "good"); err == nil {
		t.Fatal("expected error on nil hostel")
	}
	if _, err := facade.AssignHostelOccupant(101, "u", "h", "n"); err == nil {
		t.Fatal("expected error on nil hostel")
	}
	if err := facade.RemoveHostelOccupant(101, "u"); err == nil {
		t.Fatal("expected error on nil hostel")
	}
	if tt := facade.GetWeeklyMessTimetable(); tt != nil {
		t.Fatal("expected nil timetable on nil mess")
	}
	if _, err := facade.GetMessMeal("1"); err == nil {
		t.Fatal("expected error on nil mess")
	}
	if _, err := facade.UpdateMessMeal(model.MessMeal{}); err == nil {
		t.Fatal("expected error on nil mess")
	}
	if _, err := facade.SubmitMealRating(service.SubmitRatingRequest{}); err == nil {
		t.Fatal("expected error on nil mess")
	}
	_ = facade.GetMessRatingsReport("1", "all")
	if _, err := facade.CreateComplaint(model.Complaint{}); err == nil {
		t.Fatal("expected error on nil complaints")
	}
	if _, err := facade.GetComplaint("1", "v"); err == nil {
		t.Fatal("expected error on nil complaints")
	}
	if list := facade.ListComplaints("c", "s", "m", "v", nil); list != nil {
		t.Fatal("expected nil list on nil complaints")
	}
	if _, err := facade.UpdateComplaintStatus("1", "s", "r", "v"); err == nil {
		t.Fatal("expected error on nil complaints")
	}
	if _, err := facade.RaiseDispute(model.Complaint{}); err == nil {
		t.Fatal("expected error on nil complaints")
	}
	if list := facade.ListDisputes("f", "s", "m", "v", nil); list != nil {
		t.Fatal("expected nil list on nil complaints")
	}
	if _, err := facade.GetFeeSummary(ctx, "s"); err == nil {
		t.Fatal("expected error on nil fee")
	}
	if _, err := facade.GetInvoices(ctx, "s", ""); err == nil {
		t.Fatal("expected error on nil fee")
	}
	if _, err := facade.GetInvoiceByID(ctx, "1"); err == nil {
		t.Fatal("expected error on nil fee")
	}
	if _, _, err := facade.PayInvoice(ctx, model.PayInvoiceRequest{}); err == nil {
		t.Fatal("expected error on nil fee")
	}
	if _, err := facade.GetFines(ctx, "s", ""); err == nil {
		t.Fatal("expected error on nil fee")
	}
	if _, _, err := facade.PayFine(ctx, model.PayFineRequest{}); err == nil {
		t.Fatal("expected error on nil fee")
	}
	if _, err := facade.AppealFine(ctx, "1", "r"); err == nil {
		t.Fatal("expected error on nil fee")
	}
	if _, err := facade.WaiveFine(ctx, "1", "a"); err == nil {
		t.Fatal("expected error on nil fee")
	}
	if _, err := facade.GetPaymentRecords(ctx, "s"); err == nil {
		t.Fatal("expected error on nil fee")
	}
	if _, err := facade.GetReceipt(ctx, "1"); err == nil {
		t.Fatal("expected error on nil fee")
	}
	if _, _, err := facade.DownloadInvoicePDF(ctx, "1"); err == nil {
		t.Fatal("expected error on nil fee")
	}
	if _, err := facade.GetLibrarySummary(ctx, "s"); err == nil {
		t.Fatal("expected error on nil library")
	}
	if _, err := facade.GetPhysicalBooks(ctx, "", ""); err == nil {
		t.Fatal("expected error on nil library")
	}
	if _, err := facade.GetBookByID(ctx, "1"); err == nil {
		t.Fatal("expected error on nil library")
	}
	if _, err := facade.GetBorrowRecords(ctx, "s", ""); err == nil {
		t.Fatal("expected error on nil library")
	}
	if _, err := facade.BorrowBook(ctx, model.BorrowBookRequest{}); err == nil {
		t.Fatal("expected error on nil library")
	}
	if _, err := facade.ApproveBorrow(ctx, model.ApproveBorrowRequest{}); err == nil {
		t.Fatal("expected error on nil library")
	}
	if _, err := facade.RejectBorrow(ctx, model.RejectBorrowRequest{}); err == nil {
		t.Fatal("expected error on nil library")
	}
	if _, err := facade.ReturnBook(ctx, model.ReturnBookRequest{}); err == nil {
		t.Fatal("expected error on nil library")
	}
	if _, err := facade.ApproveReturn(ctx, model.ApproveReturnRequest{}); err == nil {
		t.Fatal("expected error on nil library")
	}
	if _, err := facade.RejectReturn(ctx, model.RejectReturnRequest{}); err == nil {
		t.Fatal("expected error on nil library")
	}
	if _, err := facade.RenewBook(ctx, model.RenewBookRequest{}); err == nil {
		t.Fatal("expected error on nil library")
	}
	if _, err := facade.ApproveRenewal(ctx, model.ApproveRenewalRequest{}); err == nil {
		t.Fatal("expected error on nil library")
	}
	if _, err := facade.RejectRenewal(ctx, model.RejectRenewalRequest{}); err == nil {
		t.Fatal("expected error on nil library")
	}
	if _, err := facade.GetEBooks(ctx, "", ""); err == nil {
		t.Fatal("expected error on nil library")
	}
}
