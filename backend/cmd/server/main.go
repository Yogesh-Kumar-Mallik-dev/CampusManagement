package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
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
	dbConfig := database.Config{
		Host:     "localhost",
		Port:     5432,
		User:     "campus_user",
		Password: "campus_password",
		DBName:   "campus_db",
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

	// 4. Define HTTP Routes
	mux := http.NewServeMux()

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

	// User Onboarding & ID Generation Routes
	mux.HandleFunc("/api/v1/users/student", userHandler.CreateStudent)
	mux.HandleFunc("/api/v1/users/employee", userHandler.CreateEmployee)

	// Scoped Permissions Endpoints
	mux.HandleFunc("/api/v1/permissions/assign", userHandler.AssignRole)
	mux.HandleFunc("/api/v1/permissions/check", userHandler.CheckPermission)

	// Phase 1 Academics, Timetable, Attendance & Notices
	mux.HandleFunc("/api/v1/academics/courses", academicHandler.HandleCourses)
	mux.HandleFunc("/api/v1/academics/timetable", academicHandler.HandleTimetable)
	mux.HandleFunc("/api/v1/attendance/sync", academicHandler.SyncAttendance)
	mux.HandleFunc("/api/v1/attendance/summary", academicHandler.GetAttendanceSummary)
	mux.HandleFunc("/api/v1/notices", academicHandler.HandleNotices)

	// Delta Sync Endpoint (Protected by Resilient Cache + Singleflight)
	mux.HandleFunc("/api/v1/sync", academicHandler.DeltaSync)

	server := &http.Server{
		Addr:         ":" + port,
		Handler:      mux,
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

	// 2. Seed Timetable Slots for CSE Section 3A
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
		RoomNumber:     "Lab-3",
		SlotType:       "lab",
	})
	_, _ = svc.CreateTimetableSlot(ctx, model.TimetableSlot{
		CourseID:       c3.ID,
		CourseCode:     c3.Code,
		CourseName:     c3.Name,
		ScopeCode:      "sec:cse-3a",
		InstructorName: "Dr. Sandeep Rao",
		DayOfWeek:      2, // Tuesday
		StartTime:      "11:15",
		EndTime:        "12:15",
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
}
