package main

import (
	"context"
	"encoding/json"
	"fmt"
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

	// Seed Standard Campus Roles into Permission Service
	seedDefaultRolesAndScopes(permService)

	userHandler := handler.NewUserHandler(idService, permService)

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

	// Delta Sync Endpoint (Protected by Resilient Cache + Singleflight)
	mux.HandleFunc("/api/v1/sync", func(w http.ResponseWriter, r *http.Request) {
		sinceParam := r.URL.Query().Get("since")
		cacheKey := fmt.Sprintf("sync:global:%s", sinceParam)

		data, err := cacheManager.FetchOrCompute(r.Context(), cacheKey, 3*time.Minute, func(ctx context.Context) ([]byte, error) {
			resp := model.DeltaSyncResponse{
				ServerTime: time.Now().UTC(),
				Notices: []model.Notice{
					{
						BaseSyncModel: model.BaseSyncModel{
							ID:        "notice-1",
							CreatedAt: time.Now().UTC().Add(-2 * time.Hour),
							UpdatedAt: time.Now().UTC().Add(-2 * time.Hour),
							IsDeleted: false,
						},
						Title:       "Fall Semester Registration Open",
						Content:     "Portal is active for course enrollment until next Friday.",
						Category:    "Academic",
						Publisher:   "Registrar Office",
						PublishedAt: time.Now().UTC().Add(-2 * time.Hour),
					},
				},
				Timetables: []model.TimetableEntry{},
			}
			return json.Marshal(resp)
		})

		if err != nil {
			http.Error(w, fmt.Sprintf("Error fetching data: %v", err), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write(data)
	})

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
