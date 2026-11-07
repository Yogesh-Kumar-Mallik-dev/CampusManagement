package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"campus/backend/internal/cache"
	"campus/backend/internal/database"
	"campus/backend/internal/handler"
	"campus/backend/internal/idgen"
	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	redisAddr := os.Getenv("REDIS_ADDR")
	if redisAddr == "" {
		redisAddr = "localhost:6379"
	}

	// 1. Initialize Redis Store with safe fallback
	redisStore := cache.NewRedisStore(redisAddr, "", 0)
	cacheManager := cache.NewResilientManager(redisStore)

	// 2. Initialize PostgreSQL with strictly capped connection pool
	dbHost := os.Getenv("POSTGRES_HOST")
	if dbHost == "" {
		dbHost = "localhost"
	}
	dbPortStr := os.Getenv("POSTGRES_PORT")
	dbPort := 5432
	if dbPortStr != "" {
		var p int
		if _, err := fmt.Sscanf(dbPortStr, "%d", &p); err == nil && p > 0 {
			dbPort = p
		}
	}
	dbUser := os.Getenv("POSTGRES_USER")
	if dbUser == "" {
		dbUser = "campus_user"
	}
	dbPassword := os.Getenv("POSTGRES_PASSWORD")
	if dbPassword == "" {
		dbPassword = "campus_password"
	}
	dbName := os.Getenv("POSTGRES_DB")
	if dbName == "" {
		dbName = "campus_db"
	}

	dbConfig := database.Config{
		Host:     dbHost,
		Port:     dbPort,
		User:     dbUser,
		Password: dbPassword,
		DBName:   dbName,
		MaxConns: 30,
		MinConns: 5,
	}
	dbPool, err := database.ConnectPostgres(dbConfig)
	if err != nil {
		log.Printf("[Warning] Database startup check: %v (continuing with resilient memory fallback)", err)
	}

	// 3. Initialize Services
	idService := idgen.NewIDService(dbPool)
	permService := service.NewPermissionService(dbPool, cacheManager)
	academicService := service.NewAcademicService(dbPool, cacheManager, permService)

	// Seed Standard Campus Roles into Permission Service & Sample Academic Data
	seedDefaultRolesAndScopes(permService)
	seedDefaultAcademics(academicService)

	userHandler := handler.NewUserHandler(idService, permService)
	academicHandler := handler.NewAcademicHandler(academicService)
	departmentHandler := handler.NewDepartmentHandler(academicService, userHandler.FindUser, userHandler.ListTeachers)
	authHandler := handler.NewAuthHandler(permService)

	// 4. Define HTTP Routes
	mux := http.NewServeMux()

	// Authentication Endpoints
	mux.HandleFunc("/api/v1/auth/login", authHandler.Login)

	// Health check endpoint
	mux.HandleFunc("/api/health", func(w http.ResponseWriter, r *http.Request) {
		status := map[string]interface{}{
			"status":      "ok",
			"timestamp":   time.Now().UTC(),
			"cache_ready": redisStore.IsAvailable(),
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(status)
	})

	// User Management, ID Generation & Lifecycle Routes
	mux.HandleFunc("/api/v1/users", userHandler.HandleUsers)
	mux.HandleFunc("/api/v1/users/profile", userHandler.GetUserProfile)
	mux.HandleFunc("/api/v1/users/student", userHandler.CreateStudent)
	mux.HandleFunc("/api/v1/users/employee", userHandler.CreateEmployee)
	mux.HandleFunc("/api/v1/users/contractor", userHandler.CreateContractor)
	mux.HandleFunc("/api/v1/users/discontinue", userHandler.DiscontinueUser)
	mux.HandleFunc("/api/v1/users/reactivate", userHandler.ReactivateUser)

	// Scoped Permissions Endpoints
	mux.HandleFunc("/api/v1/permissions/assign", userHandler.AssignRole)
	mux.HandleFunc("/api/v1/permissions/check", userHandler.CheckPermission)

	// Phase 1 Academics, Timetable, Attendance & Notices
	mux.HandleFunc("/api/v1/academics/courses", academicHandler.HandleCourses)
	mux.HandleFunc("/api/v1/academics/timetable", academicHandler.HandleTimetable)
	mux.HandleFunc("/api/v1/academics/timetable/check-conflict", academicHandler.HandleTimetableCheckConflict)
	mux.HandleFunc("/api/v1/academics/timetable/day-off", academicHandler.HandleTimetableDayOff)
	mux.HandleFunc("/api/v1/academics/timetable/restore-day", academicHandler.HandleTimetableRestoreDay)
	mux.HandleFunc("/api/v1/attendance/sync", academicHandler.SyncAttendance)
	mux.HandleFunc("/api/v1/attendance/summary", academicHandler.GetAttendanceSummary)
	mux.HandleFunc("/api/v1/attendance/optical/start", academicHandler.StartOpticalSession)
	mux.HandleFunc("/api/v1/attendance/optical/verify", academicHandler.VerifyOpticalAttendance)
	mux.HandleFunc("/api/v1/attendance/optical/roster", academicHandler.GetOpticalSessionRoster)
	mux.HandleFunc("/api/v1/attendance/optical/end", academicHandler.EndOpticalSession)
	mux.HandleFunc("/api/v1/notices", academicHandler.HandleNotices)

	// Departments & Academic Hierarchy (M:N and N:1)
	mux.HandleFunc("/api/v1/departments", departmentHandler.HandleDepartments)
	mux.HandleFunc("/api/v1/academics/programs", departmentHandler.HandlePrograms)
	mux.HandleFunc("/api/v1/academics/subjects", departmentHandler.HandleSubjects)
	mux.HandleFunc("/api/v1/academics/subjects/syllabus", departmentHandler.HandleSubjectSyllabus)
	mux.HandleFunc("/api/v1/academics/semesters", departmentHandler.HandleSemesters)
	mux.HandleFunc("/api/v1/academics/sections", departmentHandler.HandleSections)
	mux.HandleFunc("/api/v1/academics/sections/assign-student", departmentHandler.HandleAssignStudentToSection)
	mux.HandleFunc("/api/v1/academics/sections/transfer-student", departmentHandler.HandleTransferStudentSection)
	mux.HandleFunc("/api/v1/academics/sections/merge", departmentHandler.HandleMergeSectionCohorts)
	mux.HandleFunc("/api/v1/academics/sections/batches", departmentHandler.HandleLabBatches)
	mux.HandleFunc("/api/v1/academics/sections/batches/auto-partition", departmentHandler.HandleAutoPartitionBatches)
	mux.HandleFunc("/api/v1/academics/sections/batches/assign-student", departmentHandler.HandleAssignStudentBatch)
	mux.HandleFunc("/api/v1/academics/allocations", departmentHandler.HandleFacultyAllocations)
	mux.HandleFunc("/api/v1/academics/faculty/workload", departmentHandler.HandleFacultyWorkload)
	mux.HandleFunc("/api/v1/academics/teachers", departmentHandler.HandleTeachers)

	// Delta Sync Endpoint (Protected by Resilient Cache + Singleflight)
	mux.HandleFunc("/api/v1/sync", academicHandler.DeltaSync)

	// Locate client/build/web if built
	webDistDirs := []string{
		"../client/build/web",
		"client/build/web",
		"../../client/build/web",
	}
	var webDist string
	for _, dir := range webDistDirs {
		if fi, err := os.Stat(dir); err == nil && fi.IsDir() {
			webDist = dir
			break
		}
	}

	if webDist != "" {
		log.Printf("📱 Serving Flutter Web App at http://localhost:%s/ from %s", port, webDist)
		fs := http.FileServer(http.Dir(webDist))
		mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
			if strings.HasPrefix(r.URL.Path, "/api") {
				http.NotFound(w, r)
				return
			}
			fullPath := filepath.Join(webDist, r.URL.Path)
			if _, err := os.Stat(fullPath); os.IsNotExist(err) {
				http.ServeFile(w, r, filepath.Join(webDist, "index.html"))
				return
			}
			fs.ServeHTTP(w, r)
		})
	} else {
		// API Portal page
		mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
			if r.URL.Path != "/" {
				http.NotFound(w, r)
				return
			}
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			_, _ = w.Write([]byte(`<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>CampusOS Backend</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 700px; margin: 40px auto; padding: 20px; line-height: 1.6; }
    h1 { color: #1e40af; }
    .badge { display: inline-block; padding: 4px 8px; border-radius: 4px; background: #dbeafe; color: #1e40af; font-weight: bold; }
    ul { list-style: none; padding: 0; }
    li { margin: 10px 0; padding: 12px; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; }
    a { color: #2563eb; font-weight: 600; text-decoration: none; }
    a:hover { text-decoration: underline; }
  </style>
</head>
<body>
  <h1>🏛️ CampusOS API Backend</h1>
  <p><span class="badge">Status: Online</span> Port: 8080</p>
  <p>Available endpoints:</p>
  <ul>
    <li><a href="/api/health">/api/health</a> - System Health & Cache Readiness</li>
    <li><a href="/api/v1/sync">/api/v1/sync</a> - Delta Sync Replication Endpoint</li>
    <li><a href="/api/v1/academics/courses">/api/v1/academics/courses</a> - Academic Course Catalog</li>
    <li><a href="/api/v1/academics/timetable?scope=sec:cse-3a">/api/v1/academics/timetable?scope=sec:cse-3a</a> - Timetable</li>
    <li><a href="/api/v1/notices">/api/v1/notices</a> - Targeted Notice Board</li>
  </ul>
  <p>To run the native desktop or web Flutter client: <code>./script.sh app run</code></p>
</body>
</html>`))
		})
	}

	// Wrap mux with CORS middleware
	handlerWithCORS := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-User-ID")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}
		mux.ServeHTTP(w, r)
	})

	server := &http.Server{
		Addr:         ":" + port,
		Handler:      handlerWithCORS,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	log.Printf("🚀 Campus Management Backend running on http://localhost:%s", port)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Server stopped: %v", err)
	}
}

func seedDefaultRolesAndScopes(svc *service.PermissionService) {
	// Base Roles
	svc.AddMemoryRole(model.Role{
		Code: "student_base",
		Name: "Student Base",
		Permissions: []model.Permission{
			{Code: "timetable:view"},
			{Code: "attendance:view_self"},
			{Code: "fees:pay"},
		},
	})

	svc.AddMemoryRole(model.Role{
		Code: "class_rep",
		Name: "Class Representative",
		Permissions: []model.Permission{
			{Code: "attendance:mark"},
			{Code: "notice:section_post"},
		},
	})

	svc.AddMemoryRole(model.Role{
		Code: "club_president",
		Name: "Club President",
		Permissions: []model.Permission{
			{Code: "club:publish_event"},
			{Code: "club:spend_budget"},
			{Code: "club:manage_members"},
		},
	})

	svc.AddMemoryRole(model.Role{
		Code: "hod",
		Name: "Head of Department",
		Permissions: []model.Permission{
			{Code: "attendance:mark"},
			{Code: "attendance:approve"},
			{Code: "syllabus:approve"},
			{Code: "faculty:assign_workload"},
		},
	})

	svc.AddMemoryRole(model.Role{
		Code: "warden",
		Name: "Hostel Warden",
		Permissions: []model.Permission{
			{Code: "gatepass:approve"},
			{Code: "room:inspect"},
		},
	})

	svc.AddMemoryRole(model.Role{
		Code: "canteen_manager",
		Name: "Canteen Manager",
		Permissions: []model.Permission{
			{Code: "menu:update"},
			{Code: "coupon:redeem"},
			{Code: "sales:view"},
		},
	})

	// Scopes
	deptCSE := "dept-cse-id"
	svc.AddMemoryScope(model.Scope{
		BaseSyncModel: model.BaseSyncModel{ID: deptCSE},
		Code:          "dept:cse",
		Name:          "Computer Science & Engineering",
	})
	svc.AddMemoryScope(model.Scope{
		BaseSyncModel: model.BaseSyncModel{ID: "sec-cse-3a-id"},
		Code:          "sec:cse-3a",
		Name:          "CSE 3rd Sem Section A",
		ParentScopeID: &deptCSE,
	})
	svc.AddMemoryScope(model.Scope{
		BaseSyncModel: model.BaseSyncModel{ID: "club-robotics-id"},
		Code:          "club:robotics",
		Name:          "Robotics Club",
	})
}

func seedDefaultAcademics(svc *service.AcademicService) {
	ctx := context.Background()

	// 1. Seed Courses
	c1, _ := svc.CreateCourse(ctx, model.Course{
		Code:     "CS301",
		Name:     "Operating Systems",
		Credits:  4,
		Semester: 3,
	})
	c2, _ := svc.CreateCourse(ctx, model.Course{
		Code:     "CS302",
		Name:     "Database Management Systems",
		Credits:  4,
		Semester: 3,
	})
	c3, _ := svc.CreateCourse(ctx, model.Course{
		Code:     "CS303",
		Name:     "Design & Analysis of Algorithms",
		Credits:  4,
		Semester: 3,
	})

	// 2. Seed Timetable Slots for CSE Section 3A (9 AM to 5 PM Blocks)
	// Monday: 09:00-10:00 Lecture, 10:00-11:00 Lecture (Consecutive -> Rectangle)
	_, _ = svc.CreateTimetableSlot(ctx, model.TimetableSlot{
		CourseID:       c1.ID,
		CourseCode:     c1.Code,
		CourseName:     c1.Name,
		ScopeCode:      "sec:cse-3a",
		InstructorName: "Dr. Priya Nair",
		DayOfWeek:      1, // Monday
		StartTime:      "09:00",
		EndTime:        "10:00",
		RoomNumber:     "LH-101",
		SlotType:       "lecture",
	})
	_, _ = svc.CreateTimetableSlot(ctx, model.TimetableSlot{
		CourseID:       c2.ID,
		CourseCode:     c2.Code,
		CourseName:     c2.Name,
		ScopeCode:      "sec:cse-3a",
		InstructorName: "Prof. Amit Verma",
		DayOfWeek:      1, // Monday
		StartTime:      "10:00",
		EndTime:        "11:00",
		RoomNumber:     "LH-101",
		SlotType:       "lecture",
	})
	// Monday: 11:00-12:00 Free Period
	_, _ = svc.CreateTimetableSlot(ctx, model.TimetableSlot{
		CourseCode: "FREE",
		CourseName: "Library & Self-Study",
		ScopeCode:  "sec:cse-3a",
		DayOfWeek:  1,
		StartTime:  "11:00",
		EndTime:    "12:00",
		RoomNumber: "Central Library",
		SlotType:   "free",
	})
	// Monday: 12:00-13:00 Free Period (Midday Recess)
	_, _ = svc.CreateTimetableSlot(ctx, model.TimetableSlot{
		CourseCode: "FREE",
		CourseName: "Midday Recess & Lunch",
		ScopeCode:  "sec:cse-3a",
		DayOfWeek:  1,
		StartTime:  "12:00",
		EndTime:    "13:00",
		RoomNumber: "Campus Cafeteria",
		SlotType:   "free",
	})
	// Monday: 13:00-14:00 Lab, 14:00-15:00 Lab (Consecutive 2-Hour Lab -> Rectangle)
	_, _ = svc.CreateTimetableSlot(ctx, model.TimetableSlot{
		CourseID:       c3.ID,
		CourseCode:     c3.Code,
		CourseName:     c3.Name + " Practical Lab",
		ScopeCode:      "sec:cse-3a",
		InstructorName: "Dr. Sandeep Rao",
		DayOfWeek:      1,
		StartTime:      "13:00",
		EndTime:        "14:00",
		RoomNumber:     "Lab-3",
		SlotType:       "lab",
	})
	_, _ = svc.CreateTimetableSlot(ctx, model.TimetableSlot{
		CourseID:       c3.ID,
		CourseCode:     c3.Code,
		CourseName:     c3.Name + " Practical Lab",
		ScopeCode:      "sec:cse-3a",
		InstructorName: "Dr. Sandeep Rao",
		DayOfWeek:      1,
		StartTime:      "14:00",
		EndTime:        "15:00",
		RoomNumber:     "Lab-3",
		SlotType:       "lab",
	})
	// Monday: 15:00-16:00 Lecture (Standalone -> Square)
	_, _ = svc.CreateTimetableSlot(ctx, model.TimetableSlot{
		CourseID:       c1.ID,
		CourseCode:     c1.Code,
		CourseName:     c1.Name + " Tutorial",
		ScopeCode:      "sec:cse-3a",
		InstructorName: "Dr. Priya Nair",
		DayOfWeek:      1,
		StartTime:      "15:00",
		EndTime:        "16:00",
		RoomNumber:     "LH-101",
		SlotType:       "tutorial",
	})
	// Monday: 16:00-17:00 Declared Off (Off -> Square)
	_, _ = svc.CreateTimetableSlot(ctx, model.TimetableSlot{
		CourseCode: "OFF",
		CourseName: "Evening Dismissal",
		ScopeCode:  "sec:cse-3a",
		DayOfWeek:  1,
		StartTime:  "16:00",
		EndTime:    "17:00",
		RoomNumber: "-",
		SlotType:   "off",
	})

	// Tuesday: 11:00-12:00 Lecture
	_, _ = svc.CreateTimetableSlot(ctx, model.TimetableSlot{
		CourseID:       c3.ID,
		CourseCode:     c3.Code,
		CourseName:     c3.Name,
		ScopeCode:      "sec:cse-3a",
		InstructorName: "Dr. Sandeep Rao",
		DayOfWeek:      2, // Tuesday
		StartTime:      "11:00",
		EndTime:        "12:00",
		RoomNumber:     "LH-101",
		SlotType:       "lecture",
	})

	// 3. Seed Targeted Notices
	_, _ = svc.PublishNotice(ctx, model.Notice{
		Title:           "Mid-Semester Exam Schedule Published",
		Content:         "The midterm examination timetable is now available on the portal. Exams begin from Nov 18.",
		Category:        "exam",
		Priority:        "high",
		TargetScopeCode: "global",
	})
	_, _ = svc.PublishNotice(ctx, model.Notice{
		Title:           "OS Lab Assignment 2 Deadline Extended",
		Content:         "Submit your process scheduling simulation programs before Friday 5:00 PM.",
		Category:        "academic",
		Priority:        "normal",
		TargetScopeCode: "sec:cse-3a",
	})

	// 4. Seed Academic Programs (Overarching degree courses)
	_, _ = svc.CreateProgram(ctx, model.Program{
		Code:           "BTECH-CSE",
		Name:           "B.Tech in Computer Science & Engineering",
		DegreeLevel:    "undergraduate",
		TotalSemesters: 8,
	})
	_, _ = svc.CreateProgram(ctx, model.Program{
		Code:           "BTECH-AIML",
		Name:           "B.Tech in Artificial Intelligence & Machine Learning",
		DegreeLevel:    "undergraduate",
		TotalSemesters: 8,
	})
	_, _ = svc.CreateProgram(ctx, model.Program{
		Code:           "BTECH-DS",
		Name:           "B.Tech in Data Science",
		DegreeLevel:    "undergraduate",
		TotalSemesters: 8,
	})
	_, _ = svc.CreateProgram(ctx, model.Program{
		Code:           "BTECH-ECE",
		Name:           "B.Tech in Electronics & Communication",
		DegreeLevel:    "undergraduate",
		TotalSemesters: 8,
	})
	_, _ = svc.CreateProgram(ctx, model.Program{
		Code:           "BTECH-MECH",
		Name:           "B.Tech in Mechanical Engineering",
		DegreeLevel:    "undergraduate",
		TotalSemesters: 8,
	})

	// 5. Seed Catalog Subjects
	_, _ = svc.CreateSubject(ctx, model.Subject{
		Code:    "CS301",
		Name:    "Operating Systems",
		Credits: 4,
	})
	_, _ = svc.CreateSubject(ctx, model.Subject{
		Code:    "CS302",
		Name:    "Database Management Systems",
		Credits: 4,
	})
	_, _ = svc.CreateSubject(ctx, model.Subject{
		Code:    "CS303",
		Name:    "Design & Analysis of Algorithms",
		Credits: 4,
	})
	_, _ = svc.CreateSubject(ctx, model.Subject{
		Code:    "CS304",
		Name:    "Deep Learning & Neural Networks",
		Credits: 4,
	})
	_, _ = svc.CreateSubject(ctx, model.Subject{
		Code:    "MA101",
		Name:    "Discrete Mathematics",
		Credits: 3,
	})
	_, _ = svc.CreateSubject(ctx, model.Subject{
		Code:    "EC201",
		Name:    "Signals & Systems",
		Credits: 4,
	})

	bcaSub, _ := svc.CreateSubject(ctx, model.Subject{
		Code:        "BCA 102 / 202",
		OddSemCode:  "BCA-102",
		EvenSemCode: "BCA-202",
		Name:        "Computer Fundamentals & Problem Solving with C",
		Credits:     4,
		ActiveSyllabus: &model.SyllabusVersion{
			RevisionCode:      "Scheme-2021",
			EffectiveFromYear: "2021-2022",
			Content:           "Unit 1: Intro to Computing Architecture & Number Systems\nUnit 2: C Syntax, Control Flow & Conditionals\nUnit 3: Arrays, Strings and Pointers\nUnit 4: File I/O and Standard Libraries",
			ChangeSummary:     "Baseline curriculum ratified by Board of Studies (BoS)",
			ApprovedBy:        "Academic Council & BoS Computing",
		},
	})
	// Revise syllabus to Reg-2024 to create a historical audit trail
	_, _ = svc.ReviseSyllabus(ctx, model.ReviseSyllabusRequest{
		SubjectID:         bcaSub.ID,
		RevisionCode:      "Reg-2024",
		EffectiveFromYear: "2024-2025",
		Content:           "Unit 1: Modern Systems, Bitwise Logic & Memory Layout\nUnit 2: Structured Programming, Control Flow & Recursion\nUnit 3: Deep Dive Pointers, Dynamic Memory & Structs\nUnit 4: POSIX File I/O, Error Handling & Concurrency Basics\nUnit 5: Memory Safety Case Studies: C to Rust Comparison",
		ChangeSummary:     "Added Unit 5 Memory Safety analysis, upgraded POSIX I/O requirements for industry alignment",
		ApprovedBy:        "Board of Studies (BoS) Curriculum Reform Committee",
	})

	// 6. Seed Program Semesters
	_, _ = svc.CreateSemester(ctx, model.Semester{
		ProgramCode:    "BTECH-CSE",
		ProgramName:    "B.Tech in Computer Science & Engineering",
		SemesterNumber: 5,
		AcademicYear:   "2025-2026",
		Section:        "3A",
		DisplayName:    "B.Tech CSE - Semester 5 (Sec 3A)",
		SubjectIDs:     []string{"subj-cs301", "subj-cs302", "subj-cs303"},
		TeacherIDs:     []string{"usr-priya_2024_emp_1"},
	})
	_, _ = svc.CreateSemester(ctx, model.Semester{
		ProgramCode:    "BTECH-CSE",
		ProgramName:    "B.Tech in Computer Science & Engineering",
		SemesterNumber: 3,
		AcademicYear:   "2025-2026",
		Section:        "2A",
		DisplayName:    "B.Tech CSE - Semester 3 (Sec 2A)",
		SubjectIDs:     []string{"subj-ma101"},
		TeacherIDs:     []string{"usr-priya_2024_emp_1"},
	})
	_, _ = svc.CreateSemester(ctx, model.Semester{
		ProgramCode:    "BTECH-ECE",
		ProgramName:    "B.Tech in Electronics & Communication",
		SemesterNumber: 5,
		AcademicYear:   "2025-2026",
		Section:        "1A",
		DisplayName:    "B.Tech ECE - Semester 5 (Sec 1A)",
		SubjectIDs:     []string{"subj-ec201", "subj-ma101"},
		TeacherIDs:     []string{"usr-priya_2024_emp_1"},
	})

	// 7. Seed Departments (with M:N relations)
	hodID := "usr-priya_2024_emp_1"
	_, _ = svc.CreateDepartment(ctx, model.CreateDepartmentRequest{
		Code:        "CSE",
		Name:        "Department of Computer Science & Engineering",
		Description: "Advancing computing frontiers through cutting-edge systems, AI, and cybersecurity research.",
		HODID:       &hodID,
		SubjectIDs:  []string{"subj-cs301", "subj-cs302", "subj-cs303", "subj-ma101"},
		TeacherIDs:  []string{"usr-priya_2024_emp_1"},
		SemesterIDs: []string{"sem-btech-cse-5-3a", "sem-btech-cse-3-2a"},
	})

	_, _ = svc.CreateDepartment(ctx, model.CreateDepartmentRequest{
		Code:        "ECE",
		Name:        "Department of Electronics & Communication",
		Description: "Leading innovations in embedded robotics, VLSI architectures, and RF communication.",
		HODID:       &hodID,
		SubjectIDs:  []string{"subj-ec201", "subj-ma101"},
		TeacherIDs:  []string{"usr-priya_2024_emp_1"},
		SemesterIDs: []string{"sem-btech-ece-5-1a"},
	})

	_, _ = svc.CreateDepartment(ctx, model.CreateDepartmentRequest{
		Code:        "MATH",
		Name:        "Department of Mathematics & Computing",
		Description: "Theoretical foundational sciences, numerical computing, and applied mathematical statistics.",
		SubjectIDs:  []string{"subj-ma101"},
		TeacherIDs:  []string{"usr-priya_2024_emp_1"},
		SemesterIDs: []string{"sem-btech-cse-3-2a"},
	})

	// 8. Seed Cross-Program Sections
	deptCSEID := "dept-cse"
	// Section B (Years 1-2 cohort shared across CSE, AI/ML, and DS with common core subjects)
	secB, _ := svc.CreateSection(ctx, model.CreateSectionRequest{
		Name:           "Section B",
		SemesterNumber: 3,
		AcademicYear:   "2025-2026",
		DepartmentID:   &deptCSEID,
		ProgramIDs:     []string{"prog-btech-cse", "prog-btech-aiml", "prog-btech-ds"},
		SubjectIDs:     []string{"subj-cs301", "subj-cs302", "subj-ma101"},
		TeacherIDs:     []string{"usr-priya_2024_emp_1"},
	})
	_ = secB

	// Section A (Semester 5 shared class across CSE & AI/ML with core + program specialization)
	secA, _ := svc.CreateSection(ctx, model.CreateSectionRequest{
		Name:           "Section A",
		SemesterNumber: 5,
		AcademicYear:   "2025-2026",
		DepartmentID:   &deptCSEID,
		ProgramIDs:     []string{"prog-btech-cse", "prog-btech-aiml"},
		SubjectIDs:     []string{"subj-cs301", "subj-cs302", "subj-cs303"},
		TeacherIDs:     []string{"usr-priya_2024_emp_1"},
	})
	// Allocate AI/ML specialized elective into Section A
	progAIMLID := "prog-btech-aiml"
	_ = svc.AllocateSubjectToSection(ctx, secA.ID, model.SectionSubjectAllocation{
		SubjectID:   "subj-cs304",
		SubjectCode: "CS304",
		SubjectName: "Deep Learning & Neural Networks",
		Credits:     4,
		ProgramID:   &progAIMLID,
		ProgramCode: stringPtr("BTECH-AIML"),
		ProgramName: stringPtr("B.Tech in Artificial Intelligence & Machine Learning"),
	})

	// 9. Enroll Student Harish into Semester 5 & Section A (Degree: BTECH-CSE)
	_ = svc.AssignStudentToSemester(ctx, "usr-harish_2025_l_btech_1", "sem-btech-cse-5-3a")
	_ = svc.AssignStudentToSection(ctx, "usr-harish_2025_l_btech_1", secA.ID, "prog-btech-cse")

	// 10. Seed Lab Batches for Section B (Practical sub-divisions)
	batchB1, _ := svc.CreateLabBatch(ctx, model.CreateLabBatchRequest{
		SectionID: secB.ID,
		Name:      "Batch B1",
	})
	batchB2, _ := svc.CreateLabBatch(ctx, model.CreateLabBatchRequest{
		SectionID: secB.ID,
		Name:      "Batch B2",
	})
	_ = batchB2

	// 11. Seed Faculty Subject Allocations
	teacherPriya := "usr-priya_2024_emp_1"
	// Prof. Priya Nair -> Section A: CS301 (Theory, 4 hrs)
	_, _ = svc.AssignFacultyAllocation(ctx, model.AssignFacultyAllocationRequest{
		SectionID:     secA.ID,
		SubjectID:     "subj-cs301",
		TeacherID:     teacherPriya,
		ComponentType: "theory",
		WeeklyHours:   4,
	}, nil)

	// Prof. Priya Nair -> Section A: CS302 (Theory, 3 hrs)
	_, _ = svc.AssignFacultyAllocation(ctx, model.AssignFacultyAllocationRequest{
		SectionID:     secA.ID,
		SubjectID:     "subj-cs302",
		TeacherID:     teacherPriya,
		ComponentType: "theory",
		WeeklyHours:   3,
	}, nil)

	// Prof. Priya Nair -> Section B: BCA 102/202 (Theory, 4 hrs)
	_, _ = svc.AssignFacultyAllocation(ctx, model.AssignFacultyAllocationRequest{
		SectionID:     secB.ID,
		SubjectID:     bcaSub.ID,
		TeacherID:     teacherPriya,
		ComponentType: "theory",
		WeeklyHours:   4,
	}, nil)

	// Prof. Priya Nair -> Section B: BCA 102/202 Lab (Practical for Batch B1, 2 hrs)
	batchB1ID := batchB1.ID
	_, _ = svc.AssignFacultyAllocation(ctx, model.AssignFacultyAllocationRequest{
		SectionID:     secB.ID,
		SubjectID:     bcaSub.ID,
		TeacherID:     teacherPriya,
		ComponentType: "practical",
		BatchID:       &batchB1ID,
		WeeklyHours:   2,
	}, nil)

	// 12. Seed Student Attendance Sessions for Student Harish
	studentHarishID := "usr-harish_2025_l_btech_1"
	seedCourseAttendance := func(courseID, courseCode, courseName string, total, attended int) {
		for i := 1; i <= total; i++ {
			status := model.StatusPresent
			if i > attended {
				status = model.StatusAbsent
			}
			dateStr := fmt.Sprintf("2026-10-%02d", (i%28)+1)
			_, _ = svc.SyncAttendanceBatch(ctx, teacherPriya, model.OfflineAttendanceBatch{
				Sessions: []model.AttendanceSession{
					{
						ID:          fmt.Sprintf("sess-seed-%s-%d", courseID, i),
						CourseID:    courseID,
						CourseCode:  courseCode,
						CourseName:  courseName,
						ScopeCode:   "sec:cse-3a",
						SessionDate: dateStr,
						Topic:       fmt.Sprintf("Session %d: Foundations & Practical Applications", i),
						IsFinalized: true,
						Records: []model.AttendanceRecord{
							{
								StudentID: studentHarishID,
								Status:    status,
							},
						},
					},
				},
			})
		}
	}

	seedCourseAttendance(c1.ID, c1.Code, c1.Name, 32, 28)                                  // 87.5%
	seedCourseAttendance(c2.ID, c2.Code, c2.Name, 30, 24)                                  // 80.0%
	seedCourseAttendance(c3.ID, c3.Code, c3.Name, 24, 17)                                  // 70.8%
	seedCourseAttendance("subj-cs304", "CS304", "Deep Learning & Neural Networks", 30, 29) // 96.7%
	seedCourseAttendance("subj-ma101", "MA101", "Discrete Mathematics", 20, 12)           // 60.0%
}

func stringPtr(s string) *string {
	return &s
}
