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
}

func TestCampusFacadeNilSafety(t *testing.T) {
	ctx := context.Background()
	// Nil dependencies facade
	facade := NewCampusFacade(nil, nil, nil, nil, nil, nil)

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
}
