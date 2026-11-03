package service

import (
	"context"
	"testing"
	"time"

	"campus/backend/internal/model"
)

func TestAcademicServiceFlow(t *testing.T) {
	svc := NewAcademicService(nil, nil, nil)
	ctx := context.Background()

	// 1. Create Courses
	c1, err := svc.CreateCourse(ctx, model.Course{
		Code:     "CS301",
		Name:     "Operating Systems",
		Credits:  4,
		Semester: 3,
	})
	if err != nil || c1.Code != "CS301" {
		t.Fatalf("failed creating course: %v", err)
	}

	c2, _ := svc.CreateCourse(ctx, model.Course{
		Code:     "CS302",
		Name:     "Database Systems",
		Credits:  4,
		Semester: 3,
	})

	courses, _ := svc.ListCourses(ctx)
	if len(courses) != 2 {
		t.Fatalf("expected 2 courses, got %d", len(courses))
	}

	// 2. Timetable creation & scope filtering
	_, _ = svc.CreateTimetableSlot(ctx, model.TimetableSlot{
		CourseID:   c1.ID,
		ScopeCode:  "sec:cse-3a",
		DayOfWeek:  1, // Monday
		StartTime:  "09:00",
		EndTime:    "10:00",
		RoomNumber: "LH-101",
		SlotType:   "lecture",
	})
	_, _ = svc.CreateTimetableSlot(ctx, model.TimetableSlot{
		CourseID:   c2.ID,
		ScopeCode:  "sec:cse-3b",
		DayOfWeek:  1, // Monday
		StartTime:  "10:00",
		EndTime:    "11:00",
		RoomNumber: "LH-102",
		SlotType:   "lecture",
	})

	slots3A, _ := svc.GetTimetableForScope(ctx, "sec:cse-3a")
	if len(slots3A) != 1 || slots3A[0].CourseCode != "CS301" {
		t.Fatalf("expected 1 slot for sec:cse-3a with CS301, got %v", slots3A)
	}

	// 3. Offline Attendance Batch Sync
	studentHarishID := "usr-harish_2025_l_btech_1"
	batch := model.OfflineAttendanceBatch{
		Sessions: []model.AttendanceSession{
			{
				ID:          "sess-offline-1",
				CourseID:    c1.ID,
				ScopeCode:   "sec:cse-3a",
				SessionDate: "2026-11-03",
				Topic:       "Process Scheduling & PCB",
				Records: []model.AttendanceRecord{
					{
						StudentID: studentHarishID,
						Status:    model.StatusPresent,
					},
				},
			},
			{
				ID:          "sess-offline-2",
				CourseID:    c1.ID,
				ScopeCode:   "sec:cse-3a",
				SessionDate: "2026-11-04",
				Topic:       "Semaphores and Mutexes",
				Records: []model.AttendanceRecord{
					{
						StudentID: studentHarishID,
						Status:    model.StatusAbsent,
					},
				},
			},
		},
	}

	saved, err := svc.SyncAttendanceBatch(ctx, "usr-priya_2024_emp_1", batch)
	if err != nil || len(saved) != 2 {
		t.Fatalf("failed syncing attendance batch: %v", err)
	}

	// Check attendance summary for Harish: 1 attended out of 2 = 50%
	summary, err := svc.GetStudentAttendanceSummary(ctx, studentHarishID)
	if err != nil || len(summary) != 1 {
		t.Fatalf("failed getting attendance summary: %v", err)
	}
	if summary[0].TotalSessions != 2 || summary[0].Attended != 1 || summary[0].Percentage != 50.0 {
		t.Fatalf("expected 50%% attendance (1/2), got: %+v", summary[0])
	}

	// 4. Targeted Notices
	_, _ = svc.PublishNotice(ctx, model.Notice{
		Title:           "All Campus Holiday",
		Content:         "Campus closed for festival.",
		Category:        "general",
		TargetScopeCode: "global",
	})
	_, _ = svc.PublishNotice(ctx, model.Notice{
		Title:           "CSE 3A Quiz Postponed",
		Content:         "Quiz 1 will take place on Thursday.",
		Category:        "academic",
		TargetScopeCode: "sec:cse-3a",
	})
	_, _ = svc.PublishNotice(ctx, model.Notice{
		Title:           "Hostel Block B Inspection",
		Content:         "Routine check tomorrow at 8pm.",
		Category:        "hostel",
		TargetScopeCode: "hostel:block-b",
	})

	// Student in CSE 3A should see Global Notice + CSE 3A Notice (2 notices)
	noticesHarish, _ := svc.GetTargetedNotices(ctx, []string{"sec:cse-3a"})
	if len(noticesHarish) != 2 {
		t.Fatalf("expected 2 notices for Harish (global + 3a), got %d", len(noticesHarish))
	}

	// Student in Hostel Block B should see Global Notice + Hostel B Notice (2 notices)
	noticesHostel, _ := svc.GetTargetedNotices(ctx, []string{"hostel:block-b"})
	if len(noticesHostel) != 2 {
		t.Fatalf("expected 2 notices for Hostel B, got %d", len(noticesHostel))
	}

	// 5. Delta Sync
	oneHourAgo := time.Now().UTC().Add(-1 * time.Hour)
	syncResp, err := svc.GetDeltaSync(ctx, oneHourAgo, []string{"sec:cse-3a"})
	if err != nil {
		t.Fatalf("delta sync failed: %v", err)
	}
	if len(syncResp.Courses) != 2 || len(syncResp.TimetableSlots) != 1 || len(syncResp.Notices) != 2 {
		t.Fatalf("delta sync output mismatch: %+v", syncResp)
	}
}
