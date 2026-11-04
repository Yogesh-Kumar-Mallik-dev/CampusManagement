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
