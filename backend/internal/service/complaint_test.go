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

	// 8. Test GetComplaint and ListComplaints
	fetched, err := svc.GetComplaint(validStudentCmp.ID, "usr-student-3")
	if err != nil || fetched.ID != validStudentCmp.ID {
		t.Fatalf("expected to get complaint, got %v", fetched)
	}

	_, err = svc.GetComplaint("non-existent-id", "viewer")
	if err == nil {
		t.Fatalf("expected error for non-existent complaint")
	}

	listAll := svc.ListComplaints("", "", "", "viewer", nil)
	if len(listAll) == 0 {
		t.Fatalf("expected complaints in listAll")
	}

	listFiltered := svc.ListComplaints(model.ComplaintCategoryStudent, model.ComplaintStatusResolved, "usr-student-3", "usr-student-3", []string{model.ComplaintCategoryStudent})
	if len(listFiltered) == 0 {
		t.Fatalf("expected filtered complaints")
	}

	// Invalid status update
	_, err = svc.UpdateComplaintStatus(validStudentCmp.ID, "invalid_status", "", "admin")
	if err == nil {
		t.Fatalf("expected error for invalid status")
	}

	_, err = svc.UpdateComplaintStatus("non-existent", model.ComplaintStatusResolved, "", "admin")
	if err == nil {
		t.Fatalf("expected error for non-existent complaint update")
	}
}

func TestDisputeServiceLifecycle(t *testing.T) {
	svc := NewComplaintService()

	// 1. Verify seeded disputes
	seededDisputes := svc.ListDisputes("", "", "", "viewer", nil)
	if len(seededDisputes) < 4 {
		t.Fatalf("expected at least 4 seeded disputes, got: %d", len(seededDisputes))
	}

	// 2. Filter disputes by target type (result, fine, fee, payroll)
	resultDisputes := svc.ListDisputes(model.DisputeTargetResult, "", "", "viewer", nil)
	if len(resultDisputes) == 0 {
		t.Fatalf("expected at least 1 result dispute")
	}

	fineDisputes := svc.ListDisputes(model.DisputeTargetFine, "", "", "viewer", nil)
	if len(fineDisputes) == 0 {
		t.Fatalf("expected at least 1 fine dispute")
	}

	feeDisputes := svc.ListDisputes(model.DisputeTargetFee, "", "", "viewer", nil)
	if len(feeDisputes) == 0 {
		t.Fatalf("expected at least 1 fee dispute")
	}

	payrollDisputes := svc.ListDisputes(model.DisputeTargetPayroll, "", "", "viewer", nil)
	if len(payrollDisputes) == 0 {
		t.Fatalf("expected at least 1 payroll dispute")
	}

	// 3. Raise a new dispute (Student contesting attendance penalty)
	newDispute, err := svc.RaiseDispute(model.Complaint{
		Title:               "Dispute on CS-301 attendance debarment list",
		Description:         "Attended all classes during IEEE conference with prior sanction.",
		Category:            model.ComplaintCategoryStudent,
		Urgency:             model.ComplaintUrgencyHigh,
		IsAnonymous:         false,
		SubmittedBy:         "usr-harish_2025_l_btech_1",
		SubmitterName:       "Harish Kumar",
		SubmitterHandle:     "harish_2025_l_btech_1",
		SubmitterRole:       "student",
		DisputeTargetType:   model.DisputeTargetAttendance,
		DisputeTargetID:     "CS301-ATT-01",
		DisputeEvidence:     "OD approval letter signed by HOD Dr. Ramesh.",
		RequestedResolution: "Attendance Adjustment (+5% condonation)",
	})
	if err != nil {
		t.Fatalf("expected dispute creation to succeed, got: %v", err)
	}
	if !newDispute.IsDispute || newDispute.DisputeTargetType != model.DisputeTargetAttendance {
		t.Fatalf("unexpected dispute fields: %+v", newDispute)
	}

	// 4. Resolve the dispute
	resolved, err := svc.UpdateComplaintStatus(newDispute.ID, model.ComplaintStatusResolved, "Verified OD attendance record. Condonation granted.", "usr-ramesh_2023_emp_1")
	if err != nil {
		t.Fatalf("expected status update to succeed, got: %v", err)
	}
	if resolved.Status != model.ComplaintStatusResolved || resolved.ResolutionRemarks != "Verified OD attendance record. Condonation granted." {
		t.Fatalf("unexpected updated status: %+v", resolved)
	}
}
