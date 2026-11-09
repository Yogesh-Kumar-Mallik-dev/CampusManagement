package di

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"campus/backend/internal/cache"
	"campus/backend/internal/facade"
	"campus/backend/internal/idgen"
	"campus/backend/internal/service"
)

func TestContainerMemoryModeInitialization(t *testing.T) {
	cfg := ContainerConfig{
		UseMemoryStores: true,
	}

	container, err := NewContainer(cfg)
	if err != nil {
		t.Fatalf("failed to initialize DI container: %v", err)
	}
	defer container.Close()

	if container.CacheStore == nil {
		t.Fatal("expected CacheStore to be initialized")
	}
	if container.IDService == nil {
		t.Fatal("expected IDService to be initialized")
	}
	if container.PermissionService == nil {
		t.Fatal("expected PermissionService to be initialized")
	}
	if container.AcademicService == nil {
		t.Fatal("expected AcademicService to be initialized")
	}
	if container.HostelService == nil {
		t.Fatal("expected HostelService to be initialized")
	}
	if container.MessService == nil {
		t.Fatal("expected MessService to be initialized")
	}
	if container.ComplaintService == nil {
		t.Fatal("expected ComplaintService to be initialized")
	}
	if container.Facade == nil {
		t.Fatal("expected Facade to be initialized")
	}

	// Handlers
	if container.UserHandler == nil ||
		container.AcademicHandler == nil ||
		container.DepartmentHandler == nil ||
		container.AuthHandler == nil ||
		container.HostelHandler == nil ||
		container.MessHandler == nil ||
		container.ComplaintHandler == nil {
		t.Fatal("expected all handlers to be initialized with DI")
	}

	// Health Check
	ctx := context.Background()
	health := container.HealthCheck(ctx)
	if health["status"] != "operational" {
		t.Fatalf("expected operational health, got %v", health)
	}

	// BuildMux
	mux := container.BuildMux()
	if mux == nil {
		t.Fatal("expected non-nil ServeMux")
	}

	// Test healthz and api/health endpoints
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rr := httptest.NewRecorder()
	mux.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200 OK for /healthz, got %d", rr.Code)
	}

	reqHealth := httptest.NewRequest(http.MethodGet, "/api/health", nil)
	rrHealth := httptest.NewRecorder()
	mux.ServeHTTP(rrHealth, reqHealth)
	if rrHealth.Code != http.StatusOK {
		t.Fatalf("expected 200 OK for /api/health, got %d", rrHealth.Code)
	}
}

func TestContainerMuxWithNilHandlers(t *testing.T) {
	emptyContainer := &Container{}
	mux := emptyContainer.BuildMux()
	if mux == nil {
		t.Fatal("expected non-nil mux even with empty container")
	}

	// Test healthz still works
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rr := httptest.NewRecorder()
	mux.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200 OK for /healthz, got %d", rr.Code)
	}
}

func TestHealthCheckBranches(t *testing.T) {
	c := &Container{
		CacheStore: nil,
		DBPool:     nil,
	}
	health := c.HealthCheck(context.Background())
	if health["cache"] != "fallback" {
		t.Fatalf("expected fallback cache, got %s", health["cache"])
	}
	if health["database"] != "memory_mode" {
		t.Fatalf("expected memory_mode database, got %s", health["database"])
	}
	c.Close()
}

func TestContainerOptionOverrides(t *testing.T) {
	customStore := cache.NewMemoryStore()
	customID := idgen.NewIDService(nil)
	customPerm := service.NewPermissionService(nil, cache.NewResilientManager(customStore))
	customAcad := service.NewAcademicService(nil, cache.NewResilientManager(customStore), customPerm)
	customHostel := service.NewHostelService(nil, customPerm)
	customMess := service.NewMessService(nil, customPerm)
	customComplaint := service.NewComplaintService()
	customFee := service.NewFeeService(nil, customPerm)
	customFacade := facade.NewCampusFacade(customID, customPerm, customAcad, customHostel, customMess, customComplaint, customFee)

	container, err := NewContainer(
		ContainerConfig{UseMemoryStores: true},
		WithCacheStore(customStore),
		WithIDService(customID),
		WithPermissionService(customPerm),
		WithAcademicService(customAcad),
		WithHostelService(customHostel),
		WithMessService(customMess),
		WithComplaintService(customComplaint),
		WithFeeService(customFee),
		WithFacade(customFacade),
		WithDBPool(nil),
	)
	if err != nil {
		t.Fatalf("failed to create container with options: %v", err)
	}
	defer container.Close()

	if container.CacheStore != customStore {
		t.Fatal("custom CacheStore was not injected")
	}
	if container.IDService != customID {
		t.Fatal("custom IDService was not injected")
	}
	if container.PermissionService != customPerm {
		t.Fatal("custom PermissionService was not injected")
	}
	if container.AcademicService != customAcad {
		t.Fatal("custom AcademicService was not injected")
	}
	if container.HostelService != customHostel {
		t.Fatal("custom HostelService was not injected")
	}
	if container.MessService != customMess {
		t.Fatal("custom MessService was not injected")
	}
	if container.ComplaintService != customComplaint {
		t.Fatal("custom ComplaintService was not injected")
	}
	if container.FeeService != customFee {
		t.Fatal("custom FeeService was not injected")
	}
	if container.Facade != customFacade {
		t.Fatal("custom Facade was not injected")
	}
}

func TestNewDefaultContainer(t *testing.T) {
	container, err := NewDefaultContainer()
	if err != nil {
		t.Fatalf("failed to create default container: %v", err)
	}
	defer container.Close()

	if container == nil {
		t.Fatal("expected container")
	}
}
