package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"campus/backend/internal/idgen"
	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

func setupTestAcademicEnv(t *testing.T) (*service.AcademicService, *UserHandler, *DepartmentHandler) {
	idGen := idgen.NewIDService(nil)
	permService := service.NewPermissionService(nil, nil)
	userHandler := NewUserHandler(idGen, permService)
	academicService := service.NewAcademicService(nil, nil, permService)

	deptHandler := NewDepartmentHandler(
		academicService,
		userHandler.FindUser,
		userHandler.ListTeachers,
	)

	// Seed Sample Programs
	_, _ = academicService.CreateProgram(context.Background(), model.Program{
		Code:           "BTECH-CSE",
		Name:           "B.Tech in Computer Science & Engineering",
		DegreeLevel:    "undergraduate",
		TotalSemesters: 8,
	})
	_, _ = academicService.CreateProgram(context.Background(), model.Program{
		Code:           "BTECH-ECE",
		Name:           "B.Tech in Electronics & Communication",
		DegreeLevel:    "undergraduate",
		TotalSemesters: 8,
	})

	// Seed Sample Subjects
	_, _ = academicService.CreateSubject(context.Background(), model.Subject{
		Code:    "CS301",
		Name:    "Operating Systems",
		Credits: 4,
	})
	_, _ = academicService.CreateSubject(context.Background(), model.Subject{
		Code:    "CS302",
		Name:    "Database Management Systems",
		Credits: 4,
	})
	_, _ = academicService.CreateSubject(context.Background(), model.Subject{
		Code:    "MA101",
		Name:    "Discrete Mathematics",
		Credits: 3,
	})

	// Seed Sample Program Semesters
	_, _ = academicService.CreateSemester(context.Background(), model.Semester{
		ProgramCode:    "BTECH-CSE",
		ProgramName:    "B.Tech in Computer Science & Engineering",
		SemesterNumber: 5,
		AcademicYear:   "2025-2026",
		Section:        "3A",
		DisplayName:    "B.Tech CSE - Semester 5 (Sec 3A)",
		SubjectIDs:     []string{"subj-cs301", "subj-cs302"},
		TeacherIDs:     []string{"usr-priya_2024_emp_1"},
	})
	_, _ = academicService.CreateSemester(context.Background(), model.Semester{
		ProgramCode:    "BTECH-CSE",
		ProgramName:    "B.Tech in Computer Science & Engineering",
		SemesterNumber: 3,
		AcademicYear:   "2025-2026",
		Section:        "2A",
		DisplayName:    "B.Tech CSE - Semester 3 (Sec 2A)",
		SubjectIDs:     []string{"subj-ma101"},
		TeacherIDs:     []string{"usr-priya_2024_emp_1"},
	})

	return academicService, userHandler, deptHandler
}

func TestDepartmentCreationAndMNRelations(t *testing.T) {
	acadSvc, userHandler, deptHandler := setupTestAcademicEnv(t)
	_ = userHandler

	// 1. Create Department with M:N Subjects, Teachers, and Program Semesters
	hodID := "usr-priya_2024_emp_1"
	createPayload := model.CreateDepartmentRequest{
		Code:        "CSE",
		Name:        "Department of Computer Science & Engineering",
		Description: "Focuses on algorithms, systems, AI, and cybersecurity research.",
		HODID:       &hodID,
		SubjectIDs:  []string{"subj-cs301", "subj-cs302", "subj-ma101"},
		TeacherIDs:  []string{"usr-priya_2024_emp_1"},
		SemesterIDs: []string{"sem-btech-cse-5-3a", "sem-btech-cse-3-2a"},
	}

	body, _ := json.Marshal(createPayload)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/departments", bytes.NewReader(body))
	w := httptest.NewRecorder()
	deptHandler.HandleDepartments(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("expected status 201 Created, got %d: %s", w.Code, w.Body.String())
	}

	var created model.Department
	if err := json.NewDecoder(w.Body).Decode(&created); err != nil {
		t.Fatalf("failed to decode created department: %v", err)
	}

	if created.Code != "CSE" {
		t.Errorf("expected code 'CSE', got '%s'", created.Code)
	}
	if created.SubjectCount != 3 {
		t.Errorf("expected 3 subjects, got %d", created.SubjectCount)
	}
	if created.TeacherCount != 1 {
		t.Errorf("expected 1 teacher, got %d", created.TeacherCount)
	}
	if created.SemesterCount != 2 {
		t.Errorf("expected 2 semesters, got %d", created.SemesterCount)
	}

	// 2. List Departments via GET /api/v1/departments
	listReq := httptest.NewRequest(http.MethodGet, "/api/v1/departments", nil)
	listW := httptest.NewRecorder()
	deptHandler.HandleDepartments(listW, listReq)

	if listW.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", listW.Code)
	}

	var depts []model.Department
	if err := json.NewDecoder(listW.Body).Decode(&depts); err != nil {
		t.Fatalf("failed to decode department list: %v", err)
	}

	if len(depts) != 1 {
		t.Fatalf("expected 1 department, got %d", len(depts))
	}

	// 3. Get Department Details via GET /api/v1/departments?id=dept-cse
	detailReq := httptest.NewRequest(http.MethodGet, "/api/v1/departments?id="+created.ID, nil)
	detailW := httptest.NewRecorder()
	deptHandler.HandleDepartments(detailW, detailReq)

	if detailW.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", detailW.Code)
	}

	var detail model.DepartmentDetail
	if err := json.NewDecoder(detailW.Body).Decode(&detail); err != nil {
		t.Fatalf("failed to decode department detail: %v", err)
	}

	if len(detail.Subjects) != 3 {
		t.Errorf("expected 3 resolved subjects, got %d", len(detail.Subjects))
	}
	if len(detail.Teachers) != 1 {
		t.Errorf("expected 1 resolved teacher, got %d", len(detail.Teachers))
	}
	if len(detail.Semesters) != 2 {
		t.Errorf("expected 2 resolved semesters, got %d", len(detail.Semesters))
	}

	// 4. Test Student Many-to-One enrollment with Semester
	// Assign student Harish Kumar to Semester 5
	studentID := "usr-harish_2025_l_btech_1"
	semID := "sem-btech-cse-5-3a"
	if err := acadSvc.AssignStudentToSemester(context.Background(), studentID, semID); err != nil {
		t.Fatalf("failed to assign student to semester: %v", err)
	}

	// Inspect Semester Detail
	semReq := httptest.NewRequest(http.MethodGet, "/api/v1/academics/semesters?id="+semID, nil)
	semW := httptest.NewRecorder()
	deptHandler.HandleSemesters(semW, semReq)

	if semW.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", semW.Code)
	}

	var semDetail model.SemesterDetail
	if err := json.NewDecoder(semW.Body).Decode(&semDetail); err != nil {
		t.Fatalf("failed to decode semester detail: %v", err)
	}

	if semDetail.Semester.StudentCount != 1 {
		t.Errorf("expected 1 enrolled student, got %d", semDetail.Semester.StudentCount)
	}
	if len(semDetail.Students) != 1 {
		t.Errorf("expected 1 student in roster, got %d", len(semDetail.Students))
	} else if semDetail.Students[0].CampusHandle != "harish_2025_l_btech_1" {
		t.Errorf("expected student 'harish_2025_l_btech_1', got '%s'", semDetail.Students[0].CampusHandle)
	}

	// Reassign student to another semester (Many-to-one strictly enforces 1 active semester cohort per student)
	sem3ID := "sem-btech-cse-3-2a"
	_ = acadSvc.AssignStudentToSemester(context.Background(), studentID, sem3ID)

	sem3Detail, _ := acadSvc.GetSemesterDetail(context.Background(), sem3ID, userHandler.FindUser)
	if sem3Detail.Semester.StudentCount != 1 {
		t.Errorf("expected student in semester 3, got %d", sem3Detail.Semester.StudentCount)
	}

	sem5Detail, _ := acadSvc.GetSemesterDetail(context.Background(), semID, userHandler.FindUser)
	if sem5Detail.Semester.StudentCount != 0 {
		t.Errorf("expected student removed from semester 5 upon moving, got %d", sem5Detail.Semester.StudentCount)
	}
}

func TestDepartmentHandlerInvalidRequests(t *testing.T) {
	_, _, deptHandler := setupTestAcademicEnv(t)

	// Missing code and name
	badReq := httptest.NewRequest(http.MethodPost, "/api/v1/departments", bytes.NewReader([]byte(`{"description":"Test"}`)))
	w := httptest.NewRecorder()
	deptHandler.HandleDepartments(w, badReq)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400 Bad Request, got %d", w.Code)
	}
}

func TestCrossProgramSectionsAndStudentEnrollment(t *testing.T) {
	acadSvc, userHandler, deptHandler := setupTestAcademicEnv(t)

	// Seed AI/ML and DS programs
	_, _ = acadSvc.CreateProgram(context.Background(), model.Program{
		Code:           "BTECH-AIML",
		Name:           "B.Tech in Artificial Intelligence & Machine Learning",
		DegreeLevel:    "undergraduate",
		TotalSemesters: 8,
	})
	_, _ = acadSvc.CreateProgram(context.Background(), model.Program{
		Code:           "BTECH-DS",
		Name:           "B.Tech in Data Science",
		DegreeLevel:    "undergraduate",
		TotalSemesters: 8,
	})

	// 1. Create a Cross-Program Section shared across CSE, AI/ML, and DS
	createSecPayload := model.CreateSectionRequest{
		Name:           "Section B",
		SemesterNumber: 3,
		AcademicYear:   "2025-2026",
		ProgramIDs:     []string{"prog-btech-cse", "prog-btech-aiml", "prog-btech-ds"},
		SubjectIDs:     []string{"subj-cs301", "subj-cs302", "subj-ma101"},
		TeacherIDs:     []string{"usr-priya_2024_emp_1"},
	}

	body, _ := json.Marshal(createSecPayload)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/academics/sections", bytes.NewReader(body))
	w := httptest.NewRecorder()
	deptHandler.HandleSections(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created, got %d: %s", w.Code, w.Body.String())
	}

	var createdSec model.Section
	_ = json.Unmarshal(w.Body.Bytes(), &createdSec)
	if createdSec.Name != "Section B" {
		t.Errorf("expected Section B, got %s", createdSec.Name)
	}
	if len(createdSec.ProgramIDs) != 3 {
		t.Errorf("expected 3 programs sharing this section, got %d", len(createdSec.ProgramIDs))
	}

	// 2. Assign two students with different degree programs to the SAME Section B
	student1 := "usr-harish_2025_l_btech_1"
	assign1 := httptest.NewRequest(http.MethodPost, "/api/v1/academics/sections/assign-student", bytes.NewReader([]byte(`{
		"student_id": "`+student1+`",
		"section_id": "`+createdSec.ID+`",
		"program_id": "prog-btech-cse"
	}`)))
	w1 := httptest.NewRecorder()
	deptHandler.HandleAssignStudentToSection(w1, assign1)
	if w1.Code != http.StatusOK {
		t.Fatalf("failed to assign student 1: %d", w1.Code)
	}

	student2 := "usr-anjali_2025_l_btech_2"
	// Register student2 in userHandler
	userHandler.users[student2] = model.User{
		BaseSyncModel: model.BaseSyncModel{ID: student2},
		CampusHandle:  "anjali.sharma@campus.edu",
		FirstName:     "Anjali",
		LastName:      "Sharma",
		Archetype:     "student",
	}

	assign2 := httptest.NewRequest(http.MethodPost, "/api/v1/academics/sections/assign-student", bytes.NewReader([]byte(`{
		"student_id": "`+student2+`",
		"section_id": "`+createdSec.ID+`",
		"program_id": "prog-btech-aiml"
	}`)))
	w2 := httptest.NewRecorder()
	deptHandler.HandleAssignStudentToSection(w2, assign2)
	if w2.Code != http.StatusOK {
		t.Fatalf("failed to assign student 2: %d", w2.Code)
	}

	// 3. Inspect Section Detail and verify cohort aggregation
	detailReq := httptest.NewRequest(http.MethodGet, "/api/v1/academics/sections?id="+createdSec.ID, nil)
	wDetail := httptest.NewRecorder()
	deptHandler.HandleSections(wDetail, detailReq)

	if wDetail.Code != http.StatusOK {
		t.Fatalf("failed to get section detail: %d", wDetail.Code)
	}

	var secDetail model.SectionDetail
	_ = json.Unmarshal(wDetail.Body.Bytes(), &secDetail)

	if len(secDetail.Students) != 2 {
		t.Errorf("expected 2 students enrolled in Section B, got %d", len(secDetail.Students))
	}
	if secDetail.ProgramBreakdown["BTECH-CSE"] != 1 {
		t.Errorf("expected 1 CSE student in section, got %d", secDetail.ProgramBreakdown["BTECH-CSE"])
	}
	if secDetail.ProgramBreakdown["BTECH-AIML"] != 1 {
		t.Errorf("expected 1 AIML student in section, got %d", secDetail.ProgramBreakdown["BTECH-AIML"])
	}
	if len(secDetail.Programs) != 3 {
		t.Errorf("expected 3 programs attached to section, got %d", len(secDetail.Programs))
	}

	// 4. Test Student Section Mobility (Moving student1 from Section B to Section A)
	secAPayload := model.CreateSectionRequest{
		Name:           "Section A",
		SemesterNumber: 5,
		AcademicYear:   "2025-2026",
		ProgramIDs:     []string{"prog-btech-cse", "prog-btech-aiml"},
		SubjectIDs:     []string{"subj-cs301", "subj-cs302"},
	}
	bodyA, _ := json.Marshal(secAPayload)
	reqA := httptest.NewRequest(http.MethodPost, "/api/v1/academics/sections", bytes.NewReader(bodyA))
	wA := httptest.NewRecorder()
	deptHandler.HandleSections(wA, reqA)
	if wA.Code != http.StatusCreated {
		t.Fatalf("failed to create Section A: %d", wA.Code)
	}
	var createdSecA model.Section
	_ = json.Unmarshal(wA.Body.Bytes(), &createdSecA)

	// Move student1 to Section A
	transferReq := httptest.NewRequest(http.MethodPost, "/api/v1/academics/sections/transfer-student", bytes.NewReader([]byte(`{
		"student_id": "`+student1+`",
		"target_section_id": "`+createdSecA.ID+`"
	}`)))
	wTransfer := httptest.NewRecorder()
	deptHandler.HandleTransferStudentSection(wTransfer, transferReq)
	if wTransfer.Code != http.StatusOK {
		t.Fatalf("failed to transfer student: %d: %s", wTransfer.Code, wTransfer.Body.String())
	}

	// Verify Section B now has only 1 student, and Section A has 1
	detailBReq := httptest.NewRequest(http.MethodGet, "/api/v1/academics/sections?id="+createdSec.ID, nil)
	wBDetail := httptest.NewRecorder()
	deptHandler.HandleSections(wBDetail, detailBReq)
	var secBUpdated model.SectionDetail
	_ = json.Unmarshal(wBDetail.Body.Bytes(), &secBUpdated)
	if len(secBUpdated.Students) != 1 {
		t.Errorf("expected 1 student remaining in Section B after transfer, got %d", len(secBUpdated.Students))
	}

	// 5. Test Section Cohort Merging (Consolidation into single section in succeeding semester)
	mergeReq := httptest.NewRequest(http.MethodPost, "/api/v1/academics/sections/merge", bytes.NewReader([]byte(`{
		"source_section_id": "`+createdSec.ID+`",
		"target_section_id": "`+createdSecA.ID+`"
	}`)))
	wMerge := httptest.NewRecorder()
	deptHandler.HandleMergeSectionCohorts(wMerge, mergeReq)
	if wMerge.Code != http.StatusOK {
		t.Fatalf("failed to merge cohorts: %d: %s", wMerge.Code, wMerge.Body.String())
	}

	// Verify Section B is now consolidated (0 students) and Section A has all 2 students
	wBAfterMerge := httptest.NewRecorder()
	deptHandler.HandleSections(wBAfterMerge, httptest.NewRequest(http.MethodGet, "/api/v1/academics/sections?id="+createdSec.ID, nil))
	var secBEmpty model.SectionDetail
	_ = json.Unmarshal(wBAfterMerge.Body.Bytes(), &secBEmpty)
	if len(secBEmpty.Students) != 0 {
		t.Errorf("expected 0 students in Section B after merge, got %d", len(secBEmpty.Students))
	}

	wAAfterMerge := httptest.NewRecorder()
	deptHandler.HandleSections(wAAfterMerge, httptest.NewRequest(http.MethodGet, "/api/v1/academics/sections?id="+createdSecA.ID, nil))
	var secAFull model.SectionDetail
	_ = json.Unmarshal(wAAfterMerge.Body.Bytes(), &secAFull)
	if len(secAFull.Students) != 2 {
		t.Errorf("expected 2 students consolidated in Section A, got %d", len(secAFull.Students))
	}
}

func TestSubjectOddEvenCodesAndSyllabusAuditTrail(t *testing.T) {
	_, _, deptHandler := setupTestAcademicEnv(t)

	// 1. Create a subject with Odd and Even semester codes
	createSubPayload := model.Subject{
		OddSemCode:  "BCA-102",
		EvenSemCode: "BCA-202",
		Name:        "Computer Fundamentals & Problem Solving with C",
		Credits:     4,
		ActiveSyllabus: &model.SyllabusVersion{
			RevisionCode:      "Scheme-2021",
			EffectiveFromYear: "2021-2022",
			Content:           "Unit 1: Fundamentals. Unit 2: C Programming Syntax.",
			ChangeSummary:     "Baseline curriculum ratified by Board of Studies",
			ApprovedBy:        "Academic Council & BoS",
		},
	}

	body, _ := json.Marshal(createSubPayload)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/academics/subjects", bytes.NewReader(body))
	w := httptest.NewRecorder()
	deptHandler.HandleSubjects(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created, got %d: %s", w.Code, w.Body.String())
	}

	var createdSub model.Subject
	if err := json.Unmarshal(w.Body.Bytes(), &createdSub); err != nil {
		t.Fatalf("failed to decode created subject: %v", err)
	}

	// Verify odd / even semester resolution
	if createdSub.ResolveCodeForSemester(1) != "BCA-102" {
		t.Errorf("expected BCA-102 for odd sem 1, got %s", createdSub.ResolveCodeForSemester(1))
	}
	if createdSub.ResolveCodeForSemester(3) != "BCA-102" {
		t.Errorf("expected BCA-102 for odd sem 3, got %s", createdSub.ResolveCodeForSemester(3))
	}
	if createdSub.ResolveCodeForSemester(2) != "BCA-202" {
		t.Errorf("expected BCA-202 for even sem 2, got %s", createdSub.ResolveCodeForSemester(2))
	}
	if createdSub.ResolveCodeForSemester(4) != "BCA-202" {
		t.Errorf("expected BCA-202 for even sem 4, got %s", createdSub.ResolveCodeForSemester(4))
	}
	if createdSub.Code != "BCA-102 / BCA-202" {
		t.Errorf("expected canonical code 'BCA-102 / BCA-202', got %s", createdSub.Code)
	}

	// Verify initial syllabus is active
	if createdSub.ActiveSyllabus == nil || !createdSub.ActiveSyllabus.IsActive {
		t.Fatalf("expected active syllabus on created subject")
	}
	if createdSub.ActiveSyllabus.RevisionCode != "Scheme-2021" {
		t.Errorf("expected Scheme-2021 revision, got %s", createdSub.ActiveSyllabus.RevisionCode)
	}

	// 2. Revise Syllabus (Academic Reform 2024)
	revisePayload := model.ReviseSyllabusRequest{
		SubjectID:         createdSub.ID,
		RevisionCode:      "Reg-2024",
		EffectiveFromYear: "2024-2025",
		Content:           "Unit 1: Modern Systems. Unit 2: Advanced C. Unit 3: Concurrency & Rust Comparison.",
		ChangeSummary:     "Added Unit 3 Memory safety & Rust comparison",
		ApprovedBy:        "BoS Curriculum Reform Committee",
	}
	revBody, _ := json.Marshal(revisePayload)
	revReq := httptest.NewRequest(http.MethodPost, "/api/v1/academics/subjects/syllabus", bytes.NewReader(revBody))
	wRev := httptest.NewRecorder()
	deptHandler.HandleSubjectSyllabus(wRev, revReq)

	if wRev.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created for revise syllabus, got %d: %s", wRev.Code, wRev.Body.String())
	}

	var revisedSyl model.SyllabusVersion
	if err := json.Unmarshal(wRev.Body.Bytes(), &revisedSyl); err != nil {
		t.Fatalf("failed to decode revised syllabus: %v", err)
	}
	if !revisedSyl.IsActive {
		t.Errorf("new revision should be active")
	}
	if revisedSyl.RevisionCode != "Reg-2024" {
		t.Errorf("expected Reg-2024, got %s", revisedSyl.RevisionCode)
	}

	// 3. Query Audit Trail
	auditReq := httptest.NewRequest(http.MethodGet, "/api/v1/academics/subjects/syllabus?subject_id="+createdSub.ID, nil)
	wAudit := httptest.NewRecorder()
	deptHandler.HandleSubjectSyllabus(wAudit, auditReq)

	if wAudit.Code != http.StatusOK {
		t.Fatalf("expected 200 OK for syllabus audit trail, got %d: %s", wAudit.Code, wAudit.Body.String())
	}

	var auditTrail []model.SyllabusVersion
	if err := json.Unmarshal(wAudit.Body.Bytes(), &auditTrail); err != nil {
		t.Fatalf("failed to decode audit trail: %v", err)
	}

	if len(auditTrail) != 2 {
		t.Fatalf("expected exactly 2 syllabus versions in audit trail, got %d", len(auditTrail))
	}

	// First element should be newest (active)
	activeItem := auditTrail[0]
	if !activeItem.IsActive || activeItem.RevisionCode != "Reg-2024" {
		t.Errorf("expected newest audit item to be active Reg-2024, got %+v", activeItem)
	}
	if activeItem.EffectiveToYear != nil {
		t.Errorf("active syllabus should have nil effective_to_year")
	}

	// Second element should be previous (archived)
	archivedItem := auditTrail[1]
	if archivedItem.IsActive {
		t.Errorf("previous syllabus must be marked inactive (is_active = false)")
	}
	if archivedItem.RevisionCode != "Scheme-2021" {
		t.Errorf("expected archived item to be Scheme-2021, got %s", archivedItem.RevisionCode)
	}
	if archivedItem.EffectiveToYear == nil || *archivedItem.EffectiveToYear != "2024-2025" {
		t.Errorf("expected archived item effective_to_year to be '2024-2025', got %v", archivedItem.EffectiveToYear)
	}
}

func TestFacultySubjectAllocationAndLabBatches(t *testing.T) {
	acadSvc, _, deptHandler := setupTestAcademicEnv(t)
	ctx := context.Background()

	// 1. Create a section with 3 enrolled students
	secPayload := model.CreateSectionRequest{
		Name:           "Section B",
		SemesterNumber: 3,
		AcademicYear:   "2025-2026",
		ProgramIDs:     []string{"prog-btech-cse"},
		SubjectIDs:     []string{"subj-cs301", "subj-cs302"},
	}
	body, _ := json.Marshal(secPayload)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/academics/sections", bytes.NewReader(body))
	w := httptest.NewRecorder()
	deptHandler.HandleSections(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("failed to create section: %d", w.Code)
	}
	var sec model.Section
	_ = json.Unmarshal(w.Body.Bytes(), &sec)

	// Enroll 3 students
	_ = acadSvc.AssignStudentToSection(ctx, "usr-stud-1", sec.ID, "prog-btech-cse")
	_ = acadSvc.AssignStudentToSection(ctx, "usr-stud-2", sec.ID, "prog-btech-cse")
	_ = acadSvc.AssignStudentToSection(ctx, "usr-stud-3", sec.ID, "prog-btech-cse")

	// 2. Test AutoPartitionLabBatches into 2 batches (Batch B1 & Batch B2)
	autoPartPayload := model.AutoPartitionBatchesRequest{
		SectionID:  sec.ID,
		BatchCount: 2,
		Prefix:     "Batch B",
	}
	apBody, _ := json.Marshal(autoPartPayload)
	apReq := httptest.NewRequest(http.MethodPost, "/api/v1/academics/sections/batches/auto-partition", bytes.NewReader(apBody))
	apW := httptest.NewRecorder()
	deptHandler.HandleAutoPartitionBatches(apW, apReq)
	if apW.Code != http.StatusCreated {
		t.Fatalf("expected 201 for auto-partition, got %d: %s", apW.Code, apW.Body.String())
	}

	var createdBatches []model.LabBatch
	_ = json.Unmarshal(apW.Body.Bytes(), &createdBatches)
	if len(createdBatches) != 2 {
		t.Fatalf("expected 2 batches, got %d", len(createdBatches))
	}
	if createdBatches[0].Name != "Batch B 1" || createdBatches[1].Name != "Batch B 2" {
		t.Errorf("unexpected batch names: %s, %s", createdBatches[0].Name, createdBatches[1].Name)
	}
	// Total students partitioned must be 3 (2 in B1, 1 in B2 or vice-versa)
	totalPartitioned := createdBatches[0].StudentCount + createdBatches[1].StudentCount
	if totalPartitioned != 3 {
		t.Errorf("expected 3 students partitioned across batches, got %d", totalPartitioned)
	}

	// 3. Test Student Batch Movement
	batchB2ID := createdBatches[1].ID
	moveReq := httptest.NewRequest(http.MethodPost, "/api/v1/academics/sections/batches/assign-student", bytes.NewReader([]byte(`{
		"batch_id": "`+batchB2ID+`",
		"student_id": "usr-stud-1"
	}`)))
	moveW := httptest.NewRecorder()
	deptHandler.HandleAssignStudentBatch(moveW, moveReq)
	if moveW.Code != http.StatusOK {
		t.Fatalf("expected 200 for moving student, got %d: %s", moveW.Code, moveW.Body.String())
	}

	// 4. Test Faculty Allocations
	teacherPriya := "usr-priya_2024_emp_1"
	// Theory Allocation: Prof. Priya -> Section B, CS301 (Theory, 4 hours/week)
	theoryAllocPayload := model.AssignFacultyAllocationRequest{
		SectionID:     sec.ID,
		SubjectID:     "subj-cs301",
		TeacherID:     teacherPriya,
		ComponentType: "theory",
		WeeklyHours:   4,
	}
	tAllocBody, _ := json.Marshal(theoryAllocPayload)
	tAllocReq := httptest.NewRequest(http.MethodPost, "/api/v1/academics/allocations", bytes.NewReader(tAllocBody))
	tAllocW := httptest.NewRecorder()
	deptHandler.HandleFacultyAllocations(tAllocW, tAllocReq)
	if tAllocW.Code != http.StatusCreated {
		t.Fatalf("expected 201 for theory allocation, got %d: %s", tAllocW.Code, tAllocW.Body.String())
	}

	// Lab Practical Allocation: Prof. Priya -> Section B, CS301 Lab for Batch B1 (2 hours/week)
	batchB1ID := createdBatches[0].ID
	labAllocPayload := model.AssignFacultyAllocationRequest{
		SectionID:     sec.ID,
		SubjectID:     "subj-cs301",
		TeacherID:     teacherPriya,
		ComponentType: "practical",
		BatchID:       &batchB1ID,
		WeeklyHours:   2,
	}
	lAllocBody, _ := json.Marshal(labAllocPayload)
	lAllocReq := httptest.NewRequest(http.MethodPost, "/api/v1/academics/allocations", bytes.NewReader(lAllocBody))
	lAllocW := httptest.NewRecorder()
	deptHandler.HandleFacultyAllocations(lAllocW, lAllocReq)
	if lAllocW.Code != http.StatusCreated {
		t.Fatalf("expected 201 for lab allocation, got %d: %s", lAllocW.Code, lAllocW.Body.String())
	}

	// 5. Query Section Faculty Allocations
	secAllocReq := httptest.NewRequest(http.MethodGet, "/api/v1/academics/allocations?section_id="+sec.ID, nil)
	secAllocW := httptest.NewRecorder()
	deptHandler.HandleFacultyAllocations(secAllocW, secAllocReq)
	if secAllocW.Code != http.StatusOK {
		t.Fatalf("expected 200 for section allocations, got %d: %s", secAllocW.Code, secAllocW.Body.String())
	}
	var secAllocs []model.FacultyAllocation
	_ = json.Unmarshal(secAllocW.Body.Bytes(), &secAllocs)
	if len(secAllocs) != 2 {
		t.Fatalf("expected 2 faculty allocations for section, got %d", len(secAllocs))
	}

	// 6. Test Faculty Workload Summary
	workloadReq := httptest.NewRequest(http.MethodGet, "/api/v1/academics/faculty/workload?teacher_id="+teacherPriya, nil)
	workloadW := httptest.NewRecorder()
	deptHandler.HandleFacultyWorkload(workloadW, workloadReq)
	if workloadW.Code != http.StatusOK {
		t.Fatalf("expected 200 for workload, got %d: %s", workloadW.Code, workloadW.Body.String())
	}
	var workload model.FacultyWorkloadSummary
	_ = json.Unmarshal(workloadW.Body.Bytes(), &workload)
	if workload.TotalWeeklyHours != 6 { // 4 theory + 2 lab = 6
		t.Errorf("expected 6 total weekly hours for teacher Priya, got %d", workload.TotalWeeklyHours)
	}
	if workload.IsOverloaded {
		t.Errorf("expected teacher Priya not to be overloaded with 6 hrs")
	}

	// 7. Verify SectionDetail includes hydrated LabBatches & FacultyAllocations
	detailReq := httptest.NewRequest(http.MethodGet, "/api/v1/academics/sections?id="+sec.ID, nil)
	detailW := httptest.NewRecorder()
	deptHandler.HandleSections(detailW, detailReq)
	var secDetail model.SectionDetail
	_ = json.Unmarshal(detailW.Body.Bytes(), &secDetail)
	if len(secDetail.LabBatches) != 2 {
		t.Errorf("expected 2 hydrated lab batches in section detail, got %d", len(secDetail.LabBatches))
	}
	if len(secDetail.FacultyAllocations) != 2 {
		t.Errorf("expected 2 hydrated faculty allocations in section detail, got %d", len(secDetail.FacultyAllocations))
	}
}

