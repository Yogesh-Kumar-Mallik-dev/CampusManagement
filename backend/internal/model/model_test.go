package model

import (
	"encoding/json"
	"testing"
	"time"
)

func TestAcademicModelResolveCodeForSemester(t *testing.T) {
	subj := Subject{
		Code:        "CS101/201",
		OddSemCode:  "CS101",
		EvenSemCode: "CS201",
	}
	if code := subj.ResolveCodeForSemester(1); code != "CS101" {
		t.Fatalf("expected CS101 for odd semester 1, got %s", code)
	}
	if code := subj.ResolveCodeForSemester(2); code != "CS201" {
		t.Fatalf("expected CS201 for even semester 2, got %s", code)
	}

	subjNoEven := Subject{
		Code: "CS301",
	}
	if code := subjNoEven.ResolveCodeForSemester(2); code != "CS301" {
		t.Fatalf("expected CS301 fallback when EvenSemCode is empty, got %s", code)
	}
}

func TestComplaintModelValidationAndSanitization(t *testing.T) {
	if !SupportsAnonymous(ComplaintCategoryCampus) {
		t.Fatalf("expected Campus to support anonymous filing")
	}
	if !SupportsAnonymous(ComplaintCategoryHostel) {
		t.Fatalf("expected Hostel to support anonymous filing")
	}
	if SupportsAnonymous(ComplaintCategoryStudent) {
		t.Fatalf("expected Student to not support anonymous filing")
	}

	cmpValid := Complaint{
		SubmittedBy: "usr-1",
		Title:       "Water leakage",
		Description: "Pipe burst in Block B",
		Category:    ComplaintCategoryHostel,
		Urgency:     ComplaintUrgencyLow,
		Status:      ComplaintStatusOpen,
	}
	if err := cmpValid.Validate(); err != nil {
		t.Fatalf("expected valid complaint, got err: %v", err)
	}

	cmpMissingTitle := cmpValid
	cmpMissingTitle.Title = ""
	if err := cmpMissingTitle.Validate(); err == nil {
		t.Fatalf("expected error for empty title")
	}

	cmpMissingDesc := cmpValid
	cmpMissingDesc.Description = ""
	if err := cmpMissingDesc.Validate(); err == nil {
		t.Fatalf("expected error for empty description")
	}

	cmpBadCategory := cmpValid
	cmpBadCategory.Category = "invalid_category"
	if err := cmpBadCategory.Validate(); err == nil {
		t.Fatalf("expected error for invalid category")
	}

	// Default urgency fallback
	cmpDefaultUrgency := cmpValid
	cmpDefaultUrgency.Urgency = ""
	if err := cmpDefaultUrgency.Validate(); err != nil || cmpDefaultUrgency.Urgency != ComplaintUrgencyMedium {
		t.Fatalf("expected fallback to medium urgency, got %s", cmpDefaultUrgency.Urgency)
	}

	// Default status fallback
	cmpDefaultStatus := cmpValid
	cmpDefaultStatus.Status = ""
	if err := cmpDefaultStatus.Validate(); err != nil || cmpDefaultStatus.Status != ComplaintStatusOpen {
		t.Fatalf("expected fallback to open status, got %s", cmpDefaultStatus.Status)
	}

	cmpAnonInvalid := cmpValid
	cmpAnonInvalid.Category = ComplaintCategoryStudent
	cmpAnonInvalid.IsAnonymous = true
	if err := cmpAnonInvalid.Validate(); err == nil {
		t.Fatalf("expected error when filing anonymous for student category")
	}

	// Sanitization for viewer
	cmpAnon := Complaint{
		SubmittedBy: "usr-student-1",
		IsAnonymous: true,
		Category:    ComplaintCategoryHostel,
		Title:       "Corridor light not working",
	}
	sanitizedForOther := cmpAnon.SanitizedForViewer("usr-admin-1")
	if sanitizedForOther.SubmittedBy != "anonymous" {
		t.Fatalf("expected submitter to be anonymous for third party viewer, got %s", sanitizedForOther.SubmittedBy)
	}

	sanitizedForAuthor := cmpAnon.SanitizedForViewer("usr-student-1")
	if sanitizedForAuthor.SubmittedBy != "usr-student-1" {
		t.Fatalf("expected author to see their own ID, got %s", sanitizedForAuthor.SubmittedBy)
	}
}

func TestHostelModelValidatorsAndMethods(t *testing.T) {
	if err := ValidateRoomNumber(101); err != nil {
		t.Fatalf("expected 101 to be valid room, got %v", err)
	}
	if err := ValidateRoomNumber(99); err == nil {
		t.Fatalf("expected error for room 99")
	}
	if err := ValidateRoomNumber(1000); err == nil {
		t.Fatalf("expected error for room 1000")
	}

	if err := ValidateSerialNumber("SN-1234"); err != nil {
		t.Fatalf("expected SN-1234 to be valid serial number, got %v", err)
	}
	if err := ValidateSerialNumber(""); err == nil {
		t.Fatalf("expected error for empty serial number")
	}

	if cap := MaxCapacityForAsset(HostelAssetBed); cap != 3 {
		t.Fatalf("expected 3 beds max, got %d", cap)
	}
	if cap := MaxCapacityForAsset(HostelAssetChair); cap != 3 {
		t.Fatalf("expected 3 chairs max, got %d", cap)
	}
	if cap := MaxCapacityForAsset("unknown_asset"); cap != 0 {
		t.Fatalf("expected 0 for unknown asset, got %d", cap)
	}
	if cap := MaxCapacityForAsset(HostelAssetTubelight); cap != 2 {
		t.Fatalf("expected 2 tubelights max, got %d", cap)
	}
	if cap := MaxCapacityForAsset(HostelAssetFan); cap != 2 {
		t.Fatalf("expected 2 fans max, got %d", cap)
	}
	if cap := MaxCapacityForAsset(HostelAssetLocker); cap != 3 {
		t.Fatalf("expected 3 lockers max, got %d", cap)
	}

	room := HostelRoom{
		RoomNumber: 101,
		Floor:      1,
		BlockName:  "Block A",
		Assets: []HostelAsset{
			{AssetType: HostelAssetBed, SerialNumber: "BED-1"},
			{AssetType: HostelAssetBed, SerialNumber: "BED-2"},
			{AssetType: HostelAssetBed, SerialNumber: "BED-3"},
			{AssetType: HostelAssetTable, SerialNumber: "TAB-1"},
		},
		Occupants: []HostelOccupant{
			{UserID: "usr-stud-1"},
			{UserID: "usr-stud-2"},
			{UserID: "usr-stud-3"},
		},
	}

	if count := room.AssetCountByType(HostelAssetBed); count != 3 {
		t.Fatalf("expected 3 beds, got %d", count)
	}

	canAddBed, reason := room.CanAddAsset(HostelAssetBed)
	if canAddBed || reason == "" {
		t.Fatalf("expected cannot add 4th bed, got canAdd=%v, reason=%s", canAddBed, reason)
	}

	canAddTable, _ := room.CanAddAsset(HostelAssetTable)
	if !canAddTable {
		t.Fatalf("expected can add 2nd study table")
	}

	canAddOcc, reasonOcc := room.CanAddOccupant()
	if canAddOcc || reasonOcc == "" {
		t.Fatalf("expected cannot add 4th occupant, got canAdd=%v, reason=%s", canAddOcc, reasonOcc)
	}
}

func TestMessModelValidators(t *testing.T) {
	if err := ValidateMealForDay("monday", MealBreakfast); err != nil {
		t.Fatalf("expected monday breakfast to be valid, got %v", err)
	}
	if err := ValidateMealForDay("sunday", MealBrunch); err != nil {
		t.Fatalf("expected sunday brunch to be valid, got %v", err)
	}
	if err := ValidateMealForDay("sunday", MealBreakfast); err == nil {
		t.Fatalf("expected error for sunday breakfast")
	}
	if err := ValidateMealForDay("sunday", MealType("midnight_snack")); err == nil {
		t.Fatalf("expected error for invalid sunday meal")
	}
	if err := ValidateMealForDay("funday", MealLunch); err == nil {
		t.Fatalf("expected error for invalid day funday")
	}

	if !IsFeedbackCompulsory(RatingPoor) {
		t.Fatalf("expected poor rating to require feedback")
	}
	if !IsFeedbackCompulsory(RatingVeryPoor) {
		t.Fatalf("expected very poor rating to require feedback")
	}
	if IsFeedbackCompulsory(RatingVeryGood) {
		t.Fatalf("expected very good rating not to require feedback")
	}

	if err := ValidateRatingSubmission(RatingVeryPoor, ""); err == nil {
		t.Fatalf("expected error for very poor rating without message")
	}
	if err := ValidateRatingSubmission(RatingVeryGood, ""); err != nil {
		t.Fatalf("expected very good rating without message to pass, got %v", err)
	}
	if err := ValidateRatingSubmission(RatingValue("invalid_rating"), "good"); err == nil {
		t.Fatalf("expected error for rating value out of range")
	}
}

func TestUserModelFullName(t *testing.T) {
	user := User{
		FirstName: "John",
		LastName:  "Doe",
	}
	if name := user.FullName(); name != "John Doe" {
		t.Fatalf("expected John Doe, got %s", name)
	}

	userOnlyFirst := User{
		FirstName: "Antigravity",
	}
	if name := userOnlyFirst.FullName(); name != "Antigravity" {
		t.Fatalf("expected Antigravity, got %s", name)
	}
	userOnlyLast := User{
		LastName: "OnlyLast",
	}
	if name := userOnlyLast.FullName(); name != "OnlyLast" {
		t.Fatalf("expected OnlyLast, got %s", name)
	}
}

func TestFeeAndPaymentValidation(t *testing.T) {
	validInv := FeeInvoice{StudentID: "s1", Title: "Tuition", TotalAmount: 1000, DueAmount: 500}
	if err := validInv.Validate(); err != nil {
		t.Fatalf("expected valid invoice, got %v", err)
	}
	for _, bad := range []FeeInvoice{
		{Title: "T", TotalAmount: 10},
		{StudentID: "s1", TotalAmount: 10},
		{StudentID: "s1", Title: "T", TotalAmount: 0},
		{StudentID: "s1", Title: "T", TotalAmount: 10, DueAmount: -1},
	} {
		if err := bad.Validate(); err == nil {
			t.Fatalf("expected error for invalid invoice %+v", bad)
		}
	}

	validFine := FineRecord{StudentID: "s1", Reason: "Late book", Amount: 50}
	if err := validFine.Validate(); err != nil {
		t.Fatalf("expected valid fine, got %v", err)
	}
	for _, bad := range []FineRecord{
		{Reason: "R", Amount: 10},
		{StudentID: "s1", Amount: 10},
		{StudentID: "s1", Reason: "R", Amount: 0},
	} {
		if err := bad.Validate(); err == nil {
			t.Fatalf("expected error for invalid fine %+v", bad)
		}
	}

	validPay := CreatePaymentOrderRequest{EntityType: "invoice", EntityID: "inv-1", StudentID: "s1", Amount: 100}
	if err := validPay.Validate(); err != nil {
		t.Fatalf("expected valid payment request, got %v", err)
	}
	for _, bad := range []CreatePaymentOrderRequest{
		{EntityType: "other", EntityID: "e1", StudentID: "s1", Amount: 100},
		{EntityType: "fine", EntityID: "", StudentID: "s1", Amount: 100},
		{EntityType: "fine", EntityID: "f1", StudentID: "", Amount: 100},
		{EntityType: "fine", EntityID: "f1", StudentID: "s1", Amount: -5},
	} {
		if err := bad.Validate(); err == nil {
			t.Fatalf("expected error for invalid payment request %+v", bad)
		}
	}
}

func TestSessionalAndAcademicAndHostelModelHelpers(t *testing.T) {
	// Theory clamping and calculation
	theory := InternalAssessmentRecord{
		IsPractical: false,
		CT1Score:    35, // clamped to 30
		CT2Score:    -2, // clamped to 0
		TAScore:     12, // clamped to 10
	}
	theory.Recalculate()
	if theory.MaxInternalMarks != 30.0 || theory.CalculatedSessional != 10.0 || theory.TotalInternalMarks != 20.0 {
		t.Fatalf("unexpected theory recalculation: %+v", theory)
	}

	// Practical clamping and calculation
	prac := InternalAssessmentRecord{
		IsPractical:        true,
		LabContinuousScore: 25, // clamped to 20
		LabVivaScore:       15,
		LabAttendanceScore: 15, // clamped to 10
	}
	prac.Recalculate()
	if prac.MaxInternalMarks != 50.0 || prac.TotalInternalMarks != 45.0 {
		t.Fatalf("unexpected practical recalculation: %+v", prac)
	}

	// Signature generation
	sig := ComputeAwardListSignature("CS301", 5, []InternalAssessmentRecord{
		{UniversityRollNo: "210097", TotalInternalMarks: 25.5},
	}, "hod-1", time.Unix(1700000000, 0).UTC())
	if len(sig) != 64 {
		t.Fatalf("expected 64-char hex sha256 signature, got len=%d", len(sig))
	}

	// ProgramBranch UnmarshalJSON (string + object + invalid)
	var pb1, pb2, pb3 ProgramBranch
	if err := json.Unmarshal([]byte(`"CSE"`), &pb1); err != nil || pb1.Name != "CSE" {
		t.Fatalf("expected string unmarshal CSE, got %+v err=%v", pb1, err)
	}
	if err := json.Unmarshal([]byte(`{"name":"IT","code":"IT","is_retired":true}`), &pb2); err != nil || pb2.Code != "IT" || !pb2.IsRetired {
		t.Fatalf("expected struct unmarshal IT, got %+v err=%v", pb2, err)
	}
	if err := json.Unmarshal([]byte(`123`), &pb3); err == nil {
		t.Fatalf("expected error unmarshaling number into ProgramBranch")
	}

	// DeriveFloor boundaries
	if DeriveFloor(50) != 0 || DeriveFloor(101) != 0 || DeriveFloor(305) != 2 || DeriveFloor(900) != 4 {
		t.Fatalf("unexpected DeriveFloor outputs")
	}
}
