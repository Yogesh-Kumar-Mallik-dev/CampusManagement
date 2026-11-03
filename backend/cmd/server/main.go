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
