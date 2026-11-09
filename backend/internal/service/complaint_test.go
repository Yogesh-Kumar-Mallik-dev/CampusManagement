package service

import (
	"campus/backend/internal/model"
	"testing"
)

func TestComplaintServiceAnonymityAndValidation(t *testing.T) {
	svc := NewComplaintService()

	// 1. Valid anonymous complaint for campus
	campusCmp, err := svc.CreateComplaint(model.Complaint{
		Title:         "Broken pavement tile near library",
		Description:   "Large cracked tile causing tripping hazard.",
		Category:      model.ComplaintCategoryCampus,
		Urgency:       model.ComplaintUrgencyLow,
		IsAnonymous:   true,
		SubmittedBy:   "usr-student-1",
		SubmitterName: "Test Student",
	})
	if err != nil {
		t.Fatalf("expected campus complaint creation to succeed, got: %v", err)
	}
	if !campusCmp.IsAnonymous || campusCmp.SubmitterName != "Anonymous Reporter" {
		t.Fatalf("expected anonymous masking for campus complaint, got: %+v", campusCmp)
	}

	// 2. Valid anonymous complaint for hostel
	hostelCmp, err := svc.CreateComplaint(model.Complaint{
		Title:         "Loud music late night in 3rd floor wing",
		Description:   "Disturbing exam preparation after curfew hours.",
		Category:      model.ComplaintCategoryHostel,
		Urgency:       model.ComplaintUrgencyMedium,
		IsAnonymous:   true,
		SubmittedBy:   "usr-student-2",
		SubmitterName: "Test Student 2",
	})
	if err != nil {
		t.Fatalf("expected hostel complaint creation to succeed, got: %v", err)
	}
	if !hostelCmp.IsAnonymous || hostelCmp.SubmitterName != "Anonymous Reporter" {
		t.Fatalf("expected anonymous masking for hostel complaint, got: %+v", hostelCmp)
	}

	// 3. Invalid anonymous complaint for student (not supported)
	_, err = svc.CreateComplaint(model.Complaint{
		Title:       "Attendance percentage recorded incorrectly",
		Description: "I attended all classes on Monday but marked absent.",
		Category:    model.ComplaintCategoryStudent,
		IsAnonymous: true,
		SubmittedBy: "usr-student-3",
	})
	if err == nil {
		t.Fatalf("expected anonymous student complaint to fail validation, but it succeeded")
	}

	// 4. Invalid anonymous complaint for employee (not supported)
	_, err = svc.CreateComplaint(model.Complaint{
		Title:       "Salary calculation error for October",
		Description: "Dearness allowance not credited.",
		Category:    model.ComplaintCategoryEmployee,
		IsAnonymous: true,
		SubmittedBy: "usr-emp-1",
	})
	if err == nil {
		t.Fatalf("expected anonymous employee complaint to fail validation, but it succeeded")
	}

	// 5. Invalid anonymous complaint for contractor (not supported)
	_, err = svc.CreateComplaint(model.Complaint{
		Title:       "Invoice payment delayed past 30 days",
		Description: "Canteen groceries invoice pending clearance.",
		Category:    model.ComplaintCategoryContractor,
		IsAnonymous: true,
		SubmittedBy: "usr-ext-1",
	})
	if err == nil {
		t.Fatalf("expected anonymous contractor complaint to fail validation, but it succeeded")
	}

	// 6. Valid non-anonymous complaint for student
	validStudentCmp, err := svc.CreateComplaint(model.Complaint{
		Title:           "Attendance percentage recorded incorrectly",
		Description:     "I attended all classes on Monday but marked absent in Subject CS301.",
		Category:        model.ComplaintCategoryStudent,
		Urgency:         model.ComplaintUrgencyHigh,
		IsAnonymous:     false,
		SubmittedBy:     "usr-student-3",
		SubmitterName:   "Aakash Gupta",
		SubmitterHandle: "aakash_2025_btech",
		SubmitterRole:   "student",
	})
	if err != nil {
		t.Fatalf("expected non-anonymous student complaint to succeed, got: %v", err)
	}
	if validStudentCmp.SubmitterName != "Aakash Gupta" {
		t.Fatalf("expected submitter name to be preserved, got: %s", validStudentCmp.SubmitterName)
	}

	// 7. Update status & resolution
	resolved, err := svc.UpdateComplaintStatus(validStudentCmp.ID, model.ComplaintStatusResolved, "Corrected attendance ledger in section B.", "usr-hod-1")
	if err != nil {
		t.Fatalf("expected status update to succeed, got: %v", err)
	}
	if resolved.Status != model.ComplaintStatusResolved || resolved.ResolutionRemarks != "Corrected attendance ledger in section B." {
		t.Fatalf("unexpected updated status: %+v", resolved)
	}
}
