package service

import (
	"context"
	"testing"

	"campus/backend/internal/model"
)

func TestSessionalService_FormulaCalculations(t *testing.T) {
	svc := NewSessionalService(nil)
	ctx := context.Background()

	// 1. Check Harish Kumar's seeded records
	records, err := svc.GetRecords(ctx, "usr-harish_2025_l_btech_1", "CS301", 5)
	if err != nil {
		t.Fatalf("unexpected error getting records: %v", err)
	}
	if len(records) != 1 {
		t.Fatalf("expected 1 record for CS301, got %d", len(records))
	}

	rec := records[0]
	// Theory formula: ((CT1 + CT2) / 2) * (20/30) = (26 + 24) / 3 = 16.666... -> 16.7
	// Total: 16.7 + 8.5 (TA) = 25.2
	if rec.CalculatedSessional != 16.7 {
		t.Errorf("expected CalculatedSessional 16.7, got %.1f", rec.CalculatedSessional)
	}
	if rec.TotalInternalMarks != 25.2 {
		t.Errorf("expected TotalInternalMarks 25.2, got %.1f", rec.TotalInternalMarks)
	}
	if rec.MaxInternalMarks != 30.0 {
		t.Errorf("expected MaxInternalMarks 30.0, got %.1f", rec.MaxInternalMarks)
	}

	// 2. Check Practical Record (CS301L)
	labRecords, err := svc.GetRecords(ctx, "usr-harish_2025_l_btech_1", "CS301L", 5)
	if err != nil {
		t.Fatalf("unexpected error getting lab records: %v", err)
	}
	if len(labRecords) != 1 {
		t.Fatalf("expected 1 lab record, got %d", len(labRecords))
	}
	labRec := labRecords[0]
	// Practical formula: 18 (cont) + 17.5 (viva) + 9 (att) = 44.5
	if labRec.TotalInternalMarks != 44.5 {
		t.Errorf("expected Practical TotalInternalMarks 44.5, got %.1f", labRec.TotalInternalMarks)
	}
	if labRec.MaxInternalMarks != 50.0 {
		t.Errorf("expected Practical MaxInternalMarks 50.0, got %.1f", labRec.MaxInternalMarks)
	}
}

func TestSessionalService_RecordMarksAndValidation(t *testing.T) {
	svc := NewSessionalService(nil)
	ctx := context.Background()

	// Update CT1 and CT2 within valid bounds
	newCT1 := 29.0
	newCT2 := 30.0
	newTA := 9.5
	updated, err := svc.RecordMarks(ctx, model.UpdateMarksRequest{
		SubjectCode: "CS301",
		StudentID:   "usr-harish_2025_l_btech_1",
		CT1Score:    &newCT1,
		CT2Score:    &newCT2,
		TAScore:     &newTA,
		EnteredBy:   "dr_arun_kumar",
	})
	if err != nil {
		t.Fatalf("expected mark update to succeed, got %v", err)
	}

	// ((29 + 30) / 3) = 19.666 -> 19.7 + 9.5 = 29.2
	if updated.TotalInternalMarks != 29.2 {
		t.Errorf("expected recalculated TotalInternalMarks 29.2, got %.1f", updated.TotalInternalMarks)
	}

	// Test boundary validation: CT-1 > 30 should fail
	invalidCT1 := 35.0
	_, err = svc.RecordMarks(ctx, model.UpdateMarksRequest{
		SubjectCode: "CS301",
		StudentID:   "usr-harish_2025_l_btech_1",
		CT1Score:    &invalidCT1,
		EnteredBy:   "dr_arun_kumar",
	})
	if err == nil {
		t.Fatalf("expected error when CT-1 > 30, got nil")
	}

	// Test boundary validation: TA > 10 should fail
	invalidTA := 12.0
	_, err = svc.RecordMarks(ctx, model.UpdateMarksRequest{
		SubjectCode: "CS301",
		StudentID:   "usr-harish_2025_l_btech_1",
		TAScore:     &invalidTA,
		EnteredBy:   "dr_arun_kumar",
	})
	if err == nil {
		t.Fatalf("expected error when TA > 10, got nil")
	}
}

func TestSessionalService_FreezeMarksAndTamperProofLock(t *testing.T) {
	svc := NewSessionalService(nil)
	ctx := context.Background()

	// Freeze CS301 marks for semester 5
	awardList, err := svc.FreezeMarks(ctx, model.FreezeInternalMarksRequest{
		SubjectCode: "CS301",
		Semester:    5,
		FrozenBy:    "dr_arun_kumar",
		Remarks:     "Verified and approved by HOD for AKTU submission",
	})
	if err != nil {
		t.Fatalf("expected freeze to succeed, got %v", err)
	}

	if !awardList.IsFrozen {
		t.Errorf("expected award list to be marked frozen")
	}
	if awardList.DigitalSignature == "" {
		t.Errorf("expected digital signature hash on frozen award list")
	}
	if awardList.TotalStudents != 5 {
		t.Errorf("expected 5 students, got %d", awardList.TotalStudents)
	}

	// Verify that subsequent modification attempts are blocked
	newCT1 := 20.0
	_, err = svc.RecordMarks(ctx, model.UpdateMarksRequest{
		SubjectCode: "CS301",
		StudentID:   "usr-harish_2025_l_btech_1",
		CT1Score:    &newCT1,
		EnteredBy:   "prof_neha_sharma",
	})
	if err != ErrMarksAlreadyFrozen {
		t.Errorf("expected ErrMarksAlreadyFrozen, got %v", err)
	}
}

func TestSessionalService_SchedulesAndSeating(t *testing.T) {
	svc := NewSessionalService(nil)
	ctx := context.Background()

	// 1. Get datesheet
	schedules, err := svc.GetSchedules(ctx, 5, "CT-1")
	if err != nil {
		t.Fatalf("expected schedules, got error: %v", err)
	}
	if len(schedules) < 3 {
		t.Errorf("expected at least 3 CT-1 schedules, got %d", len(schedules))
	}

	// 2. Get seating layout
	seating, err := svc.GetSeatingLayout(ctx, "LT-101", "CT-1")
	if err != nil {
		t.Fatalf("expected seating layout, got error: %v", err)
	}
	if len(seating) != 5 {
		t.Errorf("expected 5 desks in seating layout, got %d", len(seating))
	}
	if seating[0].DeskNumber != "D-01" || seating[0].StudentRollNo != "2100970100045" {
		t.Errorf("unexpected desk 1 allocation: %+v", seating[0])
	}
}
