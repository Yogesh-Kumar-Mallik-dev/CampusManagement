package service

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
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

func TestTimetableConflictDetectionAndDayOffSync(t *testing.T) {
	ctx := context.Background()
	svc := NewAcademicService(nil, nil, nil)

	// 1. Seed initial slot: Monday 09:00 - 10:00, Section 3A, Dr. Priya Nair, Room LH-101
	slot1, err := svc.CreateTimetableSlot(ctx, model.TimetableSlot{
		CourseCode:     "CS301",
		CourseName:     "Operating Systems",
		ScopeCode:      "sec:cse-3a",
		InstructorName: "Dr. Priya Nair",
		DayOfWeek:      1,
		StartTime:      "09:00",
		EndTime:        "10:00",
		RoomNumber:     "LH-101",
		SlotType:       "lecture",
	})
	if err != nil {
		t.Fatalf("failed to create slot1: %v", err)
	}

	// 2. Check Room Conflict: Section 3B attempting to book same Room LH-101 at 09:00 on Monday
	conflictsRoom, err := svc.CheckTimetableConflicts(ctx, model.TimetableSlot{
		CourseCode:     "CS302",
		ScopeCode:      "sec:cse-3b",
		InstructorName: "Prof. Amit Verma",
		DayOfWeek:      1,
		StartTime:      "09:00",
		EndTime:        "10:00",
		RoomNumber:     "LH-101",
		SlotType:       "lecture",
	})
	if err != nil {
		t.Fatalf("check conflicts failed: %v", err)
	}
	if len(conflictsRoom) == 0 || conflictsRoom[0].Type != "room" {
		t.Fatalf("expected room conflict, got %v", conflictsRoom)
	}

	// 3. Check Instructor Conflict: Dr. Priya Nair in Section 3B in a different room (LH-102) at 09:00 on Monday
	conflictsInst, err := svc.CheckTimetableConflicts(ctx, model.TimetableSlot{
		CourseCode:     "CS303",
		ScopeCode:      "sec:cse-3b",
		InstructorName: "Dr. Priya Nair",
		DayOfWeek:      1,
		StartTime:      "09:00",
		EndTime:        "10:00",
		RoomNumber:     "LH-102",
		SlotType:       "lecture",
	})
	if err != nil {
		t.Fatalf("check conflicts failed: %v", err)
	}
	if len(conflictsInst) == 0 || conflictsInst[0].Type != "instructor" {
		t.Fatalf("expected instructor conflict, got %v", conflictsInst)
	}

	// 4. Check Section Conflict: Same Section 3A scheduled for another class at 09:00 on Monday
	conflictsSection, err := svc.CheckTimetableConflicts(ctx, model.TimetableSlot{
		CourseCode:     "MATH301",
		ScopeCode:      "sec:cse-3a",
		InstructorName: "Prof. Amit Verma",
		DayOfWeek:      1,
		StartTime:      "09:00",
		EndTime:        "10:00",
		RoomNumber:     "LH-102",
		SlotType:       "lecture",
	})
	if err != nil {
		t.Fatalf("check conflicts failed: %v", err)
	}
	if len(conflictsSection) == 0 || conflictsSection[0].Type != "section" {
		t.Fatalf("expected section conflict, got %v", conflictsSection)
	}

	// 5. Valid slot with no conflicts (different section, room, instructor)
	conflictsNone, err := svc.CheckTimetableConflicts(ctx, model.TimetableSlot{
		CourseCode:     "CS304",
		ScopeCode:      "sec:cse-3b",
		InstructorName: "Dr. Sandeep Rao",
		DayOfWeek:      1,
		StartTime:      "09:00",
		EndTime:        "10:00",
		RoomNumber:     "Lab-3",
		SlotType:       "lab",
	})
	if err != nil {
		t.Fatalf("check conflicts failed: %v", err)
	}
	if len(conflictsNone) != 0 {
		t.Fatalf("expected 0 conflicts, got %v", conflictsNone)
	}

	// 6. Test Declare Day Off & Restore Day Schedule
	err = svc.DeclareDayOff(ctx, model.DayOffRequest{
		DayOfWeek: 1,
		ScopeCode: "sec:cse-3a",
		Reason:    "Campus Sports Gala",
	})
	if err != nil {
		t.Fatalf("failed to declare day off: %v", err)
	}

	slotsOff, err := svc.GetTimetableForScope(ctx, "sec:cse-3a")
	if err != nil {
		t.Fatalf("failed to get slots: %v", err)
	}
	if len(slotsOff) != 8 {
		t.Fatalf("expected 8 day-off slots, got %d", len(slotsOff))
	}
	for _, s := range slotsOff {
		if s.SlotType != "off" {
			t.Fatalf("expected all slots to be off, got %s", s.SlotType)
		}
	}

	// Restore Day Schedule
	err = svc.RestoreDaySchedule(ctx, model.RestoreDayRequest{
		DayOfWeek: 1,
		ScopeCode: "sec:cse-3a",
	})
	if err != nil {
		t.Fatalf("failed to restore day schedule: %v", err)
	}

	slotsRestored, err := svc.GetTimetableForScope(ctx, "sec:cse-3a")
	if err != nil {
		t.Fatalf("failed to get restored slots: %v", err)
	}
	if len(slotsRestored) != 1 || slotsRestored[0].ID != slot1.ID {
		t.Fatalf("expected original slot1 to be restored, got %v", slotsRestored)
	}
}

func TestAcademicHierarchyAndOperations(t *testing.T) {
	svc := NewAcademicService(nil, nil, nil)
	ctx := context.Background()

	userResolver := func(id string) (model.User, bool) {
		return model.User{
			BaseSyncModel: model.BaseSyncModel{ID: id},
			CampusHandle:  "prof_sharma",
			FirstName:     "Prof",
			LastName:      "Sharma",
			Archetype:     "employee",
		}, true
	}
	studentProgramResolver := func(id string) string {
		return "prog-btech-cse"
	}
	teacherProvider := func() []model.User {
		return []model.User{
			{
				BaseSyncModel: model.BaseSyncModel{ID: "usr-faculty-1"},
				CampusHandle:  "prof_sharma",
				FirstName:     "Prof",
				LastName:      "Sharma",
				Archetype:     "employee",
			},
		}
	}

	// 1. Optical Attendance Session flow
	optSession, err := svc.StartOpticalSession(ctx, model.OpticalAttendanceSession{
		CourseID:        "crs-101",
		CourseCode:      "CS101",
		CourseName:      "Intro to CS",
		RoomNumber:      "LH-1",
		ScopeCode:       "sec:cse-1a",
		MarkedByUserID:  "usr-faculty-1",
		MarkedByName:    "Prof Sharma",
		RefreshInterval: 1500,
	})
	if err != nil || optSession == nil {
		t.Fatalf("failed to start optical session: %v", err)
	}

	// Verify attendance
	nowTs := time.Now().Unix()
	nonce := "testnonce123"
	seq := 1
	dataPayload := fmt.Sprintf("%s:%d:%d:%s", optSession.ID, seq, nowTs, nonce)
	mac := hmac.New(sha256.New, []byte(optSession.SessionSecret))
	mac.Write([]byte(dataPayload))
	sig := hex.EncodeToString(mac.Sum(nil))

	verifyRes, err := svc.VerifyOpticalAttendance(ctx, model.OpticalVerificationRequest{
		SessionID:   optSession.ID,
		StudentID:   "usr-student-1",
		StudentName: "Harish Kumar",
		Handle:      "harish_student",
		Sequence:    seq,
		Timestamp:   nowTs,
		Nonce:       nonce,
		Signature:   sig,
	})
	if err != nil || verifyRes == nil || !verifyRes.Verified {
		t.Fatalf("optical verification failed: %v", err)
	}

	// Session roster
	roster, err := svc.GetOpticalSessionRoster(ctx, optSession.ID)
	if err != nil || len(roster) != 1 {
		t.Fatalf("expected 1 record in roster, got %d", len(roster))
	}

	// End optical session
	endedSess, err := svc.EndOpticalSession(ctx, optSession.ID)
	if err != nil || endedSess == nil {
		t.Fatalf("failed to end optical session: %v", err)
	}

	// 2. Department Management
	hodID := "usr-hod-1"
	dept, err := svc.CreateDepartment(ctx, model.CreateDepartmentRequest{
		Code:  "CSE",
		Name:  "Computer Science and Engineering",
		HODID: &hodID,
	})
	if err != nil || dept.Code != "CSE" {
		t.Fatalf("failed to create department: %v", err)
	}

	depts, err := svc.ListDepartments(ctx)
	if err != nil || len(depts) == 0 {
		t.Fatalf("expected departments list, got %v", depts)
	}

	deptDetail, err := svc.GetDepartmentDetail(ctx, dept.ID, userResolver)
	if err != nil || deptDetail.Department.Code != "CSE" {
		t.Fatalf("failed to get department detail: %v", err)
	}

	// 3. Program Management
	prog, err := svc.CreateProgram(ctx, model.Program{
		Code:           "BTECH-CSE",
		Name:           "B.Tech Computer Science",
		DegreeLevel:    "undergraduate",
		TotalSemesters: 8,
	})
	if err != nil || prog.Code != "BTECH-CSE" {
		t.Fatalf("failed to create program: %v", err)
	}

	progs, err := svc.ListPrograms(ctx)
	if err != nil || len(progs) == 0 {
		t.Fatalf("failed to list programs: %v", progs)
	}

	// 4. Subject Management and Syllabus Audit Trail
	sub, err := svc.CreateSubject(ctx, model.Subject{
		Code:          "CS201",
		Name:          "Data Structures",
		DepartmentIDs: []string{dept.ID},
		Credits:       4,
	})
	if err != nil || sub.Name != "Data Structures" {
		t.Fatalf("failed to create subject: %v", err)
	}

	subjects, err := svc.ListSubjects(ctx)
	if err != nil || len(subjects) == 0 {
		t.Fatalf("failed to list subjects: %v", subjects)
	}

	sylVersion, err := svc.ReviseSyllabus(ctx, model.ReviseSyllabusRequest{
		SubjectID:         sub.ID,
		RevisionCode:      "Rev-2026-v1",
		EffectiveFromYear: "2026-2027",
		Content:           "Updated Unit 1: Graph algorithms and trees",
		ChangeSummary:     "Added Dijkstra & A*",
		ApprovedBy:        "BoS Committee",
	})
	if err != nil || sylVersion.SubjectID != sub.ID {
		t.Fatalf("failed to revise syllabus: %v", err)
	}

	auditTrail, err := svc.GetSubjectSyllabusAuditTrail(ctx, sub.ID)
	if err != nil || len(auditTrail) == 0 {
		t.Fatalf("expected audit trail for syllabus, got %v", auditTrail)
	}

	// 5. Semester Management
	sem, err := svc.CreateSemester(ctx, model.Semester{
		ProgramID:      prog.ID,
		SemesterNumber: 3,
		AcademicYear:   "2026-2027",
	})
	if err != nil || sem.SemesterNumber != 3 {
		t.Fatalf("failed to create semester: %v", err)
	}

	sems, err := svc.ListSemesters(ctx)
	if err != nil || len(sems) == 0 {
		t.Fatalf("failed to list semesters: %v", sems)
	}

	semDetail, err := svc.GetSemesterDetail(ctx, sem.ID, userResolver)
	if err != nil || semDetail.Semester.ID != sem.ID {
		t.Fatalf("failed to get semester detail: %v", err)
	}

	err = svc.AssignStudentToSemester(ctx, "usr-student-1", sem.ID)
	if err != nil {
		t.Fatalf("failed to assign student to semester: %v", err)
	}

	// 6. Section Management & Operations
	sec, err := svc.CreateSection(ctx, model.CreateSectionRequest{
		Name:           "CSE-3A",
		SemesterNumber: 3,
		AcademicYear:   "2026-2027",
		ProgramIDs:     []string{prog.ID},
	})
	if err != nil || sec.Name != "CSE-3A" {
		t.Fatalf("failed to create section: %v", err)
	}

	sec2, err := svc.CreateSection(ctx, model.CreateSectionRequest{
		Name:           "CSE-3B",
		SemesterNumber: 3,
		AcademicYear:   "2026-2027",
		ProgramIDs:     []string{prog.ID},
	})
	if err != nil || sec2.Name != "CSE-3B" {
		t.Fatalf("failed to create section 2: %v", err)
	}

	sections, err := svc.ListSections(ctx)
	if err != nil || len(sections) < 2 {
		t.Fatalf("failed to list sections: %v", sections)
	}

	err = svc.AssignStudentToSection(ctx, "usr-student-1", sec.ID, prog.ID)
	if err != nil {
		t.Fatalf("failed to assign student to section: %v", err)
	}

	secDetail, err := svc.GetSectionDetail(ctx, sec.ID, userResolver, studentProgramResolver)
	if err != nil || secDetail.Section.ID != sec.ID {
		t.Fatalf("failed to get section detail: %v", err)
	}

	// Transfer student
	err = svc.TransferStudentSection(ctx, "usr-student-1", sec2.ID)
	if err != nil {
		t.Fatalf("failed to transfer student section: %v", err)
	}

	// Merge cohorts
	mergedCount, err := svc.MergeSectionCohorts(ctx, sec2.ID, sec.ID)
	if err != nil || mergedCount < 1 {
		t.Fatalf("failed to merge cohorts: %v (count: %d)", err, mergedCount)
	}

	// Allocate subject
	err = svc.AllocateSubjectToSection(ctx, sec.ID, model.SectionSubjectAllocation{
		SubjectID: sub.ID,
	})
	if err != nil {
		t.Fatalf("failed to allocate subject: %v", err)
	}

	// 7. Lab Batches
	batch, err := svc.CreateLabBatch(ctx, model.CreateLabBatchRequest{
		SectionID: sec.ID,
		Name:      "Batch B1",
	})
	if err != nil || batch.Name != "Batch B1" {
		t.Fatalf("failed to create lab batch: %v", err)
	}

	partitioned, err := svc.AutoPartitionLabBatches(ctx, model.AutoPartitionBatchesRequest{
		SectionID:  sec.ID,
		BatchCount: 2,
		Prefix:     "Batch B",
	})
	if err != nil || len(partitioned) == 0 {
		t.Fatalf("failed to auto-partition lab batches: %v", err)
	}

	err = svc.AssignStudentToLabBatch(ctx, partitioned[0].ID, "usr-student-1")
	if err != nil {
		t.Fatalf("failed to assign student to lab batch: %v", err)
	}

	batches, err := svc.GetSectionLabBatches(ctx, sec.ID)
	if err != nil || len(batches) == 0 {
		t.Fatalf("failed to get section lab batches: %v", batches)
	}

	// 8. Faculty Allocations & Workload Summary
	alloc, err := svc.AssignFacultyAllocation(ctx, model.AssignFacultyAllocationRequest{
		SectionID:     sec.ID,
		TeacherID:     "usr-faculty-1",
		SubjectID:     sub.ID,
		ComponentType: "theory",
		WeeklyHours:   4,
	}, userResolver)
	if err != nil || alloc.TeacherID != "usr-faculty-1" {
		t.Fatalf("failed to assign faculty allocation: %v", err)
	}

	allocs, err := svc.GetSectionFacultyAllocations(ctx, sec.ID)
	if err != nil || len(allocs) == 0 {
		t.Fatalf("failed to get section faculty allocations: %v", allocs)
	}

	workload, err := svc.GetFacultyWorkloadSummary(ctx, "usr-faculty-1", userResolver)
	if err != nil || workload.TeacherID != "usr-faculty-1" {
		t.Fatalf("failed to get faculty workload summary: %v", err)
	}

	allWorkloads, err := svc.GetAllFacultyWorkloadSummaries(ctx, userResolver, teacherProvider)
	if err != nil || len(allWorkloads) == 0 {
		t.Fatalf("failed to get all faculty workload summaries: %v", allWorkloads)
	}

	err = svc.RemoveFacultyAllocation(ctx, alloc.ID)
	if err != nil {
		t.Fatalf("failed to remove faculty allocation: %v", err)
	}

	// 9. Department, Semester, Section details
	deptD, err := svc.GetDepartmentDetail(ctx, dept.ID, userResolver)
	if err != nil || deptD.Department.ID != dept.ID {
		t.Fatalf("failed to get department detail: %v", err)
	}

	_, err = svc.GetDepartmentDetail(ctx, "missing-dept-id", userResolver)
	if err == nil {
		t.Fatalf("expected error for missing department detail")
	}

	semD, err := svc.GetSemesterDetail(ctx, sem.ID, userResolver)
	if err != nil || semD.Semester.ID != sem.ID {
		t.Fatalf("failed to get semester detail: %v", err)
	}

	_, err = svc.GetSemesterDetail(ctx, "missing-sem-id", userResolver)
	if err == nil {
		t.Fatalf("expected error for missing semester detail")
	}

	secD, err := svc.GetSectionDetail(ctx, sec.ID, userResolver, studentProgramResolver)
	if err != nil || secD.Section.ID != sec.ID {
		t.Fatalf("failed to get section detail: %v", err)
	}

	_, err = svc.GetSectionDetail(ctx, "missing-sec-id", userResolver, studentProgramResolver)
	if err == nil {
		t.Fatalf("expected error for missing section detail")
	}

	// 10. Timetable Slot Update & Delete
	newSlot := model.TimetableSlot{
		CourseID:   "crs-cs101",
		CourseCode: "CS101",
		CourseName: "Algorithms",
		ScopeCode:  "sec:cse-3a",
	}
	createdSlot, err := svc.CreateTimetableSlot(ctx, newSlot)
	if err != nil {
		t.Fatalf("failed to create timetable slot: %v", err)
	}

	createdSlot.RoomNumber = "LH-105"
	updatedSlot, err := svc.UpdateTimetableSlot(ctx, createdSlot)
	if err != nil || updatedSlot.RoomNumber != "LH-105" {
		t.Fatalf("failed to update timetable slot: %v", err)
	}

	// Update non-existing slot creates it
	nonExistingSlot := model.TimetableSlot{
		ID:         "slot-direct-update",
		CourseID:   "crs-cs101",
		RoomNumber: "LH-106",
	}
	_, err = svc.UpdateTimetableSlot(ctx, nonExistingSlot)
	if err != nil {
		t.Fatalf("failed to update non-existing timetable slot: %v", err)
	}

	// Delete valid slot
	err = svc.DeleteTimetableSlot(ctx, createdSlot.ID)
	if err != nil {
		t.Fatalf("failed to delete timetable slot: %v", err)
	}

	// Delete non-existing slot returns error
	err = svc.DeleteTimetableSlot(ctx, "non-existing-slot-id")
	if err == nil {
		t.Fatalf("expected error deleting non-existing timetable slot")
	}

	// 11. ReviseSyllabus error validation
	_, err = svc.ReviseSyllabus(ctx, model.ReviseSyllabusRequest{
		SubjectID:         "missing-sub",
		RevisionCode:      "Rev-1",
		EffectiveFromYear: "2026",
	})
	if err == nil {
		t.Fatalf("expected error for missing subject in ReviseSyllabus")
	}

	_, err = svc.ReviseSyllabus(ctx, model.ReviseSyllabusRequest{
		SubjectID:    sub.ID,
		RevisionCode: "",
	})
	if err == nil {
		t.Fatalf("expected error for empty revision code")
	}

	_, err = svc.ReviseSyllabus(ctx, model.ReviseSyllabusRequest{
		SubjectID:         sub.ID,
		RevisionCode:      "Rev-2",
		EffectiveFromYear: "",
	})
	if err == nil {
		t.Fatalf("expected error for empty effective from year")
	}

	// 12. AllocateSubjectToSection
	err = svc.AllocateSubjectToSection(ctx, sec.ID, model.SectionSubjectAllocation{
		SubjectID: sub.ID,
	})
	if err != nil {
		t.Fatalf("failed to allocate subject to section: %v", err)
	}
}
