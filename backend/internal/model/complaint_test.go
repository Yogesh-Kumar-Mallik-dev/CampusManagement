package model_test

import (
	"campus/backend/internal/model"
	"testing"
)

func TestComplaintValidationAndDisputeRules(t *testing.T) {
	// 1. General complaint validation
	validC := model.Complaint{
		Title:       "Broken bench in central library",
		Description: "Wooden slat broken on 3rd floor reading room bench.",
		Category:    model.ComplaintCategoryCampus,
		Urgency:     model.ComplaintUrgencyLow,
		IsAnonymous: true,
	}
	if err := validC.Validate(); err != nil {
		t.Fatalf("expected valid complaint to pass, got: %v", err)
	}

	// 2. Anonymous not allowed for student category
	invalidAnon := model.Complaint{
		Title:       "Attendance mismatch",
		Description: "Marked absent despite being present in lecture.",
		Category:    model.ComplaintCategoryStudent,
		IsAnonymous: true,
	}
	if err := invalidAnon.Validate(); err == nil {
		t.Fatalf("expected error for anonymous student complaint")
	}

	// 3. Dispute: Anonymous strictly prohibited
	anonDispute := model.Complaint{
		Title:               "Dispute on library late fine",
		Description:         "Book was dropped before curfew in drop box.",
		Category:            model.ComplaintCategoryStudent,
		IsDispute:           true,
		IsAnonymous:         true,
		DisputeTargetType:   model.DisputeTargetFine,
		DisputeTargetID:     "fine-lib-01",
		RequestedResolution: "Full Fine Waiver",
	}
	if err := anonDispute.Validate(); err == nil {
		t.Fatalf("expected error for anonymous dispute submission")
	}

	// 4. Dispute: Missing target reference ID
	missingTargetId := model.Complaint{
		Title:               "Dispute on tuition fee",
		Description:         "Duplicate computer lab surcharge.",
		Category:            model.ComplaintCategoryStudent,
		IsDispute:           true,
		IsAnonymous:         false,
		DisputeTargetType:   model.DisputeTargetFee,
		DisputeTargetID:     "",
		RequestedResolution: "Fee Correction",
	}
	if err := missingTargetId.Validate(); err == nil {
		t.Fatalf("expected error for missing dispute target ID")
	}

	// 5. Dispute: Missing requested resolution
	missingResolution := model.Complaint{
		Title:               "Dispute on CS301 midterm exam result",
		Description:         "Q4 dynamic programming points not tabulated in gradebook.",
		Category:            model.ComplaintCategoryStudent,
		IsDispute:           true,
		IsAnonymous:         false,
		DisputeTargetType:   model.DisputeTargetResult,
		DisputeTargetID:     "CS301-Midterm",
		RequestedResolution: "",
	}
	if err := missingResolution.Validate(); err == nil {
		t.Fatalf("expected error for missing requested resolution")
	}

	// 6. Dispute: Invalid target type
	invalidType := model.Complaint{
		Title:               "Random dispute",
		Description:         "Some claim without recognized target type.",
		Category:            model.ComplaintCategoryStudent,
		IsDispute:           true,
		IsAnonymous:         false,
		DisputeTargetType:   "unsupported_type",
		DisputeTargetID:     "xyz-99",
		RequestedResolution: "Do something",
	}
	if err := invalidType.Validate(); err == nil {
		t.Fatalf("expected error for invalid dispute target type")
	}

	// 7. Valid Student Dispute (Result / Grading)
	validResultDispute := model.Complaint{
		Title:               "Grade tabulation discrepancy in CS-301 Midterm",
		Description:         "Q4 (10 marks) was evaluated correct in script but entered as 0 in gradebook.",
		IsDispute:           true,
		IsAnonymous:         false,
		DisputeTargetType:   model.DisputeTargetResult,
		DisputeTargetID:     "CS301-Midterm",
		DisputeEvidence:     "Physical answer sheet signed by course instructor shows 10/10.",
		RequestedResolution: "Grade Recalculation (+10 marks)",
	}
	if err := validResultDispute.Validate(); err != nil {
		t.Fatalf("expected valid result dispute to pass, got: %v", err)
	}
	if validResultDispute.Category != model.ComplaintCategoryStudent {
		t.Fatalf("expected default category student, got: %s", validResultDispute.Category)
	}

	// 8. Valid Staff Dispute (Payroll)
	validPayrollDispute := model.Complaint{
		Title:               "Conference travel allowance omitted from October payroll",
		Description:         "Approved travel reimbursement ref DEAN/TR/2026/89 missing.",
		IsDispute:           true,
		IsAnonymous:         false,
		DisputeTargetType:   model.DisputeTargetPayroll,
		DisputeTargetID:     "PAYROLL-2026-10",
		DisputeEvidence:     "Dean approval letter and boarding passes submitted.",
		RequestedResolution: "Reimbursement Credit of ₹12,000",
	}
	if err := validPayrollDispute.Validate(); err != nil {
		t.Fatalf("expected valid payroll dispute to pass, got: %v", err)
	}
	if validPayrollDispute.Category != model.ComplaintCategoryEmployee {
		t.Fatalf("expected default category employee for payroll, got: %s", validPayrollDispute.Category)
	}

	// 9. Check IsValidDisputeTargetType helper
	if !model.IsValidDisputeTargetType(model.DisputeTargetFine) ||
		!model.IsValidDisputeTargetType(model.DisputeTargetFee) ||
		!model.IsValidDisputeTargetType(model.DisputeTargetResult) ||
		!model.IsValidDisputeTargetType(model.DisputeTargetAttendance) ||
		!model.IsValidDisputeTargetType(model.DisputeTargetPayroll) ||
		!model.IsValidDisputeTargetType(model.DisputeTargetOther) {
		t.Fatalf("expected standard dispute targets to be valid")
	}
	if model.IsValidDisputeTargetType("invalid_type") {
		t.Fatalf("expected invalid type to be false")
	}
}
