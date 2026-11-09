package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"campus/backend/internal/di"
	"campus/backend/internal/service"
)

func TestServerContainerInitializationAndRouting(t *testing.T) {
	container, err := di.NewContainer(di.ContainerConfig{UseMemoryStores: true})
	if err != nil {
		t.Fatalf("failed to initialize container: %v", err)
	}
	defer container.Close()

	if concretePerm, ok := container.PermissionService.(*service.PermissionService); ok {
		seedDefaultRolesAndScopes(concretePerm)
	}
	if concreteAcad, ok := container.AcademicService.(*service.AcademicService); ok {
		seedDefaultAcademics(concreteAcad)
	}

	mux := container.BuildMux()

	// Test Health Endpoint
	req := httptest.NewRequest(http.MethodGet, "/api/health", nil)
	rr := httptest.NewRecorder()
	mux.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200 OK from /api/health, got %d", rr.Code)
	}

	// Test Delta Sync Endpoint
	reqSync := httptest.NewRequest(http.MethodGet, "/api/v1/sync?scope=global&since=0", nil)
	rrSync := httptest.NewRecorder()
	mux.ServeHTTP(rrSync, reqSync)
	if rrSync.Code != http.StatusOK {
		t.Fatalf("expected 200 OK from /api/v1/sync, got %d", rrSync.Code)
	}

	// Test Academics Courses Endpoint
	reqCourses := httptest.NewRequest(http.MethodGet, "/api/v1/academics/courses", nil)
	rrCourses := httptest.NewRecorder()
	mux.ServeHTTP(rrCourses, reqCourses)
	if rrCourses.Code != http.StatusOK {
		t.Fatalf("expected 200 OK from /api/v1/academics/courses, got %d", rrCourses.Code)
	}

	// Test Timetable Endpoint
	reqTimetable := httptest.NewRequest(http.MethodGet, "/api/v1/academics/timetable?scope=sec:cse-3a", nil)
	rrTimetable := httptest.NewRecorder()
	mux.ServeHTTP(rrTimetable, reqTimetable)
	if rrTimetable.Code != http.StatusOK {
		t.Fatalf("expected 200 OK from /api/v1/academics/timetable, got %d", rrTimetable.Code)
	}

	// Verify HealthCheck subsystem
	health := container.HealthCheck(context.Background())
	if health["status"] != "operational" {
		t.Fatalf("expected operational status, got %s", health["status"])
	}
}
