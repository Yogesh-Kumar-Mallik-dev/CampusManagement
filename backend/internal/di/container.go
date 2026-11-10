package di

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
	"campus/backend/internal/facade"
	"campus/backend/internal/handler"
	"campus/backend/internal/idgen"
	"campus/backend/internal/model"
	"campus/backend/internal/service"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ContainerConfig holds initial infrastructure configuration
type ContainerConfig struct {
	DBHost          string
	DBPort          int
	DBUser          string
	DBPassword      string
	DBName          string
	RedisAddr       string
	UseMemoryStores bool
}

// Container serves as the Dependency Injection registry for the backend system
type Container struct {
	Config       ContainerConfig
	DBPool       *pgxpool.Pool
	CacheStore   cache.Store
	CacheManager *cache.ResilientManager

	IDService         idgen.IDServiceInterface
	PermissionService service.PermissionServiceInterface
	AcademicService   service.AcademicServiceInterface
	HostelService     service.HostelServiceInterface
	MessService       service.MessServiceInterface
	ComplaintService  service.ComplaintServiceInterface
	FeeService        service.FeeServiceInterface
	LibraryService    service.LibraryServiceInterface
	SessionalService  service.SessionalServiceInterface
	DigiLockerService service.DigiLockerServiceInterface
	PaymentService    service.PaymentServiceInterface

	Facade facade.CampusFacadeInterface

	UserHandler        *handler.UserHandler
	AcademicHandler    *handler.AcademicHandler
	DepartmentHandler  *handler.DepartmentHandler
	AuthHandler        *handler.AuthHandler
	HostelHandler      *handler.HostelHandler
	MessHandler        *handler.MessHandler
	ComplaintHandler   *handler.ComplaintHandler
	FeeHandler         *handler.FeeHandler
	LibraryHandler     *handler.LibraryHandler
	SessionalHandler   *handler.SessionalHandler
	DigiLockerHandler  *handler.DigiLockerHandler
	PaymentHandler     *handler.PaymentHandler
}

// Option allows customizing/mocking dependencies during container initialization
type Option func(*Container)

func WithCacheStore(store cache.Store) Option {
	return func(c *Container) {
		c.CacheStore = store
		c.CacheManager = cache.NewResilientManager(store)
	}
}

func WithDBPool(pool *pgxpool.Pool) Option {
	return func(c *Container) {
		c.DBPool = pool
	}
}

func WithIDService(svc idgen.IDServiceInterface) Option {
	return func(c *Container) {
		c.IDService = svc
	}
}

func WithPermissionService(svc service.PermissionServiceInterface) Option {
	return func(c *Container) {
		c.PermissionService = svc
	}
}

func WithAcademicService(svc service.AcademicServiceInterface) Option {
	return func(c *Container) {
		c.AcademicService = svc
	}
}

func WithHostelService(svc service.HostelServiceInterface) Option {
	return func(c *Container) {
		c.HostelService = svc
	}
}

func WithMessService(svc service.MessServiceInterface) Option {
	return func(c *Container) {
		c.MessService = svc
	}
}

func WithComplaintService(svc service.ComplaintServiceInterface) Option {
	return func(c *Container) {
		c.ComplaintService = svc
	}
}

func WithFeeService(svc service.FeeServiceInterface) Option {
	return func(c *Container) {
		c.FeeService = svc
	}
}

func WithLibraryService(svc service.LibraryServiceInterface) Option {
	return func(c *Container) {
		c.LibraryService = svc
	}
}

func WithSessionalService(svc service.SessionalServiceInterface) Option {
	return func(c *Container) {
		c.SessionalService = svc
	}
}

func WithDigiLockerService(svc service.DigiLockerServiceInterface) Option {
	return func(c *Container) {
		c.DigiLockerService = svc
	}
}

func WithPaymentService(svc service.PaymentServiceInterface) Option {
	return func(c *Container) {
		c.PaymentService = svc
	}
}

func WithFacade(f facade.CampusFacadeInterface) Option {
	return func(c *Container) {
		c.Facade = f
	}
}

// NewContainer wires up all dependencies using Dependency Injection
func NewContainer(cfg ContainerConfig, opts ...Option) (*Container, error) {
	c := &Container{Config: cfg}

	// 1. Initialize Cache
	if cfg.UseMemoryStores || cfg.RedisAddr == "" {
		c.CacheStore = cache.NewMemoryStore()
	} else {
		c.CacheStore = cache.NewRedisStore(cfg.RedisAddr, "", 0)
	}
	c.CacheManager = cache.NewResilientManager(c.CacheStore)

	// 2. Initialize Database if configured
	if !cfg.UseMemoryStores && cfg.DBHost != "" {
		dbConfig := database.Config{
			Host:     cfg.DBHost,
			Port:     cfg.DBPort,
			User:     cfg.DBUser,
			Password: cfg.DBPassword,
			DBName:   cfg.DBName,
			MaxConns: 30,
			MinConns: 5,
		}
		pool, err := database.ConnectPostgres(dbConfig)
		if err != nil {
			log.Printf("[DI Notice] Postgres initial connect error: %v (falling back to memory)", err)
		} else {
			c.DBPool = pool
		}
	}

	// 3. Initialize Core Domain Services with Inversion of Control
	idSvc := idgen.NewIDService(c.DBPool)
	permSvc := service.NewPermissionService(c.DBPool, c.CacheManager)
	c.IDService = idSvc
	c.PermissionService = permSvc
	c.AcademicService = service.NewAcademicService(c.DBPool, c.CacheManager, permSvc)
	c.HostelService = service.NewHostelService(c.DBPool, permSvc)
	c.MessService = service.NewMessService(c.DBPool, permSvc)
	c.ComplaintService = service.NewComplaintService()
	c.FeeService = service.NewFeeService(c.DBPool, permSvc)
	c.LibraryService = service.NewLibraryService(c.DBPool, c.FeeService)
	c.SessionalService = service.NewSessionalService(permSvc)

	// Apply overrides/mocks
	for _, opt := range opts {
		opt(c)
	}

	// Seed defaults
	if concretePerm, ok := c.PermissionService.(*service.PermissionService); ok {
		seedDefaultRoles(concretePerm)
	}
	if concreteHostel, ok := c.HostelService.(*service.HostelService); ok {
		concreteHostel.SeedDefaultRooms()
	}
	if concreteMess, ok := c.MessService.(*service.MessService); ok {
		concreteMess.SeedDefaultMenuAndReviews()
	}

	// 4. Initialize Unified Domain Facade
	if c.Facade == nil {
		c.Facade = facade.NewCampusFacade(
			c.IDService,
			c.PermissionService,
			c.AcademicService,
			c.HostelService,
			c.MessService,
			c.ComplaintService,
			c.FeeService,
			c.LibraryService,
		)
	}

	// 5. Initialize Handlers with Injected Interfaces
	c.UserHandler = handler.NewUserHandler(c.IDService, c.PermissionService)
	c.AcademicHandler = handler.NewAcademicHandler(c.AcademicService)
	c.DepartmentHandler = handler.NewDepartmentHandler(
		c.AcademicService,
		c.UserHandler.FindUser,
		c.UserHandler.ListTeachers,
	)
	c.AuthHandler = handler.NewAuthHandler(c.PermissionService)
	c.HostelHandler = handler.NewHostelHandler(c.HostelService)
	c.MessHandler = handler.NewMessHandler(c.MessService)
	c.ComplaintHandler = handler.NewComplaintHandler(c.ComplaintService)
	c.FeeHandler = handler.NewFeeHandler(c.FeeService)
	c.LibraryHandler = handler.NewLibraryHandler(c.LibraryService)
	c.SessionalHandler = handler.NewSessionalHandler(c.SessionalService)

	if c.DigiLockerService == nil {
		c.DigiLockerService = service.NewDigiLockerService(
			service.DefaultDigiLockerConfig(),
			func(id string) (*model.StudentProfile, bool) {
				if c.UserHandler != nil {
					return c.UserHandler.GetStudentProfile(id)
				}
				return nil, false
			},
			func(sp model.StudentProfile) {
				if c.UserHandler != nil {
					c.UserHandler.UpdateStudentProfile(sp)
				}
			},
		)
	}
	c.DigiLockerHandler = handler.NewDigiLockerHandler(c.DigiLockerService)

	if c.PaymentService == nil {
		c.PaymentService = service.NewPaymentService(c.FeeService)
	}
	c.PaymentHandler = handler.NewPaymentHandler(c.PaymentService)

	return c, nil
}

// BuildMux routes all endpoints to handlers exactly as expected by clients
func (c *Container) BuildMux() *http.ServeMux {
	mux := http.NewServeMux()

	// Authentication Endpoints
	if c.AuthHandler != nil {
		mux.HandleFunc("/api/v1/auth/login", c.AuthHandler.Login)
	}

	// Health check endpoints
	mux.HandleFunc("/api/health", func(w http.ResponseWriter, r *http.Request) {
		status := map[string]interface{}{
			"status":      "ok",
			"timestamp":   time.Now().UTC(),
			"cache_ready": c.CacheStore != nil && c.CacheStore.IsAvailable(),
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(status)
	})
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintf(w, `{"status":"ok","engine":"campus-di-container"}`)
	})

	// User Management, ID Generation & Lifecycle Routes
	if c.UserHandler != nil {
		mux.HandleFunc("/api/v1/users", c.UserHandler.HandleUsers)
		mux.HandleFunc("/api/v1/users/profile", c.UserHandler.GetUserProfile)
		mux.HandleFunc("/api/v1/users/profile/update", c.UserHandler.UpdateUserProfile)
		mux.HandleFunc("/api/v1/users/roles", c.UserHandler.GetUserRoles)
		mux.HandleFunc("/api/v1/users/student", c.UserHandler.CreateStudent)
		mux.HandleFunc("/api/v1/users/employee", c.UserHandler.CreateEmployee)
		mux.HandleFunc("/api/v1/users/contractor", c.UserHandler.CreateContractor)
		mux.HandleFunc("/api/v1/users/discontinue", c.UserHandler.DiscontinueUser)
		mux.HandleFunc("/api/v1/users/reactivate", c.UserHandler.ReactivateUser)
		mux.HandleFunc("/api/v1/permissions/assign", c.UserHandler.AssignRole)
		mux.HandleFunc("/api/v1/permissions/check", c.UserHandler.CheckPermission)
	}

	// Phase 1 Academics, Timetable, Attendance & Notices
	if c.AcademicHandler != nil {
		mux.HandleFunc("/api/v1/academics/courses", c.AcademicHandler.HandleCourses)
		mux.HandleFunc("/api/v1/academics/timetable", c.AcademicHandler.HandleTimetable)
		mux.HandleFunc("/api/v1/academics/timetable/check-conflict", c.AcademicHandler.HandleTimetableCheckConflict)
		mux.HandleFunc("/api/v1/academics/timetable/day-off", c.AcademicHandler.HandleTimetableDayOff)
		mux.HandleFunc("/api/v1/academics/timetable/restore-day", c.AcademicHandler.HandleTimetableRestoreDay)
		mux.HandleFunc("/api/v1/attendance/sync", c.AcademicHandler.SyncAttendance)
		mux.HandleFunc("/api/v1/attendance/summary", c.AcademicHandler.GetAttendanceSummary)
		mux.HandleFunc("/api/v1/attendance/optical/start", c.AcademicHandler.StartOpticalSession)
		mux.HandleFunc("/api/v1/attendance/optical/verify", c.AcademicHandler.VerifyOpticalAttendance)
		mux.HandleFunc("/api/v1/attendance/optical/roster", c.AcademicHandler.GetOpticalSessionRoster)
		mux.HandleFunc("/api/v1/attendance/optical/end", c.AcademicHandler.EndOpticalSession)
		mux.HandleFunc("/api/v1/notices", c.AcademicHandler.HandleNotices)
		mux.HandleFunc("/api/v1/sync", c.AcademicHandler.DeltaSync)
	}

	// Departments & Academic Hierarchy
	if c.DepartmentHandler != nil {
		mux.HandleFunc("/api/v1/departments", c.DepartmentHandler.HandleDepartments)
		mux.HandleFunc("/api/v1/academics/programs", c.DepartmentHandler.HandlePrograms)
		mux.HandleFunc("/api/v1/academics/subjects", c.DepartmentHandler.HandleSubjects)
		mux.HandleFunc("/api/v1/academics/subjects/syllabus", c.DepartmentHandler.HandleSubjectSyllabus)
		mux.HandleFunc("/api/v1/academics/semesters", c.DepartmentHandler.HandleSemesters)
		mux.HandleFunc("/api/v1/academics/sections", c.DepartmentHandler.HandleSections)
		mux.HandleFunc("/api/v1/academics/sections/assign-student", c.DepartmentHandler.HandleAssignStudentToSection)
		mux.HandleFunc("/api/v1/academics/sections/transfer-student", c.DepartmentHandler.HandleTransferStudentSection)
		mux.HandleFunc("/api/v1/academics/sections/merge", c.DepartmentHandler.HandleMergeSectionCohorts)
		mux.HandleFunc("/api/v1/academics/sections/batches", c.DepartmentHandler.HandleLabBatches)
		mux.HandleFunc("/api/v1/academics/sections/batches/auto-partition", c.DepartmentHandler.HandleAutoPartitionBatches)
		mux.HandleFunc("/api/v1/academics/sections/batches/assign-student", c.DepartmentHandler.HandleAssignStudentBatch)
		mux.HandleFunc("/api/v1/academics/allocations", c.DepartmentHandler.HandleFacultyAllocations)
		mux.HandleFunc("/api/v1/academics/faculty/workload", c.DepartmentHandler.HandleFacultyWorkload)
		mux.HandleFunc("/api/v1/academics/teachers", c.DepartmentHandler.HandleTeachers)
	}

	// Residential & Hostel
	if c.HostelHandler != nil {
		mux.HandleFunc("/api/v1/hostel/rooms", c.HostelHandler.HandleRooms)
		mux.HandleFunc("/api/v1/hostel/rooms/assets", c.HostelHandler.HandleAssets)
		mux.HandleFunc("/api/v1/hostel/rooms/occupants", c.HostelHandler.HandleOccupants)
	}

	// Dining & Mess
	if c.MessHandler != nil {
		mux.HandleFunc("/api/v1/mess/timetable", c.MessHandler.HandleTimetable)
		mux.HandleFunc("/api/v1/mess/meals", c.MessHandler.HandleMeals)
		mux.HandleFunc("/api/v1/mess/ratings", c.MessHandler.HandleRatings)
	}

	// Grievances, Complaints & Dispute Redressal System
	if c.ComplaintHandler != nil {
		mux.HandleFunc("/api/v1/complaints", c.ComplaintHandler.HandleComplaints)
		mux.HandleFunc("/api/v1/complaints/status", c.ComplaintHandler.HandleComplaintStatus)
		mux.HandleFunc("/api/v1/disputes", c.ComplaintHandler.HandleComplaints)
	}

	// Institutional Fee & Fine Management System
	if c.FeeHandler != nil {
		mux.HandleFunc("/api/v1/fees/summary", c.FeeHandler.HandleSummary)
		mux.HandleFunc("/api/v1/fees/invoices", c.FeeHandler.HandleInvoices)
		mux.HandleFunc("/api/v1/fees/invoices/pdf", c.FeeHandler.HandleInvoicePDF)
		mux.HandleFunc("/api/v1/fees/pay", c.FeeHandler.HandlePayInvoice)
		mux.HandleFunc("/api/v1/fees/fines", c.FeeHandler.HandleFines)
		mux.HandleFunc("/api/v1/fees/fines/pay", c.FeeHandler.HandlePayFine)
		mux.HandleFunc("/api/v1/fees/fines/appeal", c.FeeHandler.HandleAppealFine)
		mux.HandleFunc("/api/v1/fees/fines/waive", c.FeeHandler.HandleWaiveFine)
		mux.HandleFunc("/api/v1/fees/payments", c.FeeHandler.HandlePayments)
		mux.HandleFunc("/api/v1/fees/receipt", c.FeeHandler.HandleReceipt)
	}

	// Institutional Library Management System
	if c.LibraryHandler != nil {
		mux.HandleFunc("/api/v1/library/summary", c.LibraryHandler.HandleSummary)
		mux.HandleFunc("/api/v1/library/books", c.LibraryHandler.HandleBooks)
		mux.HandleFunc("/api/v1/library/borrows", c.LibraryHandler.HandleBorrows)
		mux.HandleFunc("/api/v1/library/borrow", c.LibraryHandler.HandleBorrowBook)
		mux.HandleFunc("/api/v1/library/borrow/approve", c.LibraryHandler.HandleApproveBorrow)
		mux.HandleFunc("/api/v1/library/borrow/reject", c.LibraryHandler.HandleRejectBorrow)
		mux.HandleFunc("/api/v1/library/return", c.LibraryHandler.HandleReturnBook)
		mux.HandleFunc("/api/v1/library/return/approve", c.LibraryHandler.HandleApproveReturn)
		mux.HandleFunc("/api/v1/library/return/reject", c.LibraryHandler.HandleRejectReturn)
		mux.HandleFunc("/api/v1/library/renew", c.LibraryHandler.HandleRenewBook)
		mux.HandleFunc("/api/v1/library/renew/approve", c.LibraryHandler.HandleApproveRenewal)
		mux.HandleFunc("/api/v1/library/renew/reject", c.LibraryHandler.HandleRejectRenewal)
		mux.HandleFunc("/api/v1/library/ebooks", c.LibraryHandler.HandleEBooks)
		mux.HandleFunc("/api/v1/library/ebooks/approve", c.LibraryHandler.HandleApproveEBook)
		mux.HandleFunc("/api/v1/library/ebooks/reject", c.LibraryHandler.HandleRejectEBook)
	}

	// AKTU Sessional & Continuous Internal Evaluation
	if c.SessionalHandler != nil {
		mux.HandleFunc("/api/v1/sessional/records", c.SessionalHandler.HandleRecords)
		mux.HandleFunc("/api/v1/sessional/marks", c.SessionalHandler.HandleMarks)
		mux.HandleFunc("/api/v1/sessional/freeze", c.SessionalHandler.HandleFreeze)
		mux.HandleFunc("/api/v1/sessional/schedule", c.SessionalHandler.HandleSchedule)
		mux.HandleFunc("/api/v1/sessional/seating", c.SessionalHandler.HandleSeating)
		mux.HandleFunc("/api/v1/sessional/award-list", c.SessionalHandler.HandleAwardList)
	}

	// Government DigiLocker & APAAR Integration
	if c.DigiLockerHandler != nil {
		mux.HandleFunc("/api/v1/digilocker/auth-url", c.DigiLockerHandler.GenerateAuthURL)
		mux.HandleFunc("/api/v1/digilocker/exchange", c.DigiLockerHandler.ExchangeToken)
		mux.HandleFunc("/api/v1/digilocker/status", c.DigiLockerHandler.GetStatus)
		mux.HandleFunc("/api/v1/digilocker/disconnect", c.DigiLockerHandler.Disconnect)
	}

	// Institutional Payment Gateway & Settlement Routes
	if c.PaymentHandler != nil {
		mux.HandleFunc("/api/v1/payments/config", c.PaymentHandler.HandleConfig)
		mux.HandleFunc("/api/v1/payments/order", c.PaymentHandler.HandleCreateOrder)
		mux.HandleFunc("/api/v1/payments/verify", c.PaymentHandler.HandleVerifyPayment)
		mux.HandleFunc("/api/v1/payments/webhook", c.PaymentHandler.HandleWebhook)
	}

	return mux
}

// HealthCheck verifies subsystem connectivity
func (c *Container) HealthCheck(ctx context.Context) map[string]string {
	status := make(map[string]string)

	if c.CacheStore != nil && c.CacheStore.IsAvailable() {
		status["cache"] = "healthy"
	} else {
		status["cache"] = "fallback"
	}

	if c.DBPool != nil {
		if err := c.DBPool.Ping(ctx); err == nil {
			status["database"] = "healthy"
		} else {
			status["database"] = "unreachable"
		}
	} else {
		status["database"] = "memory_mode"
	}

	status["status"] = "operational"
	return status
}

// Close gracefully releases infrastructure resources
func (c *Container) Close() {
	if c.DBPool != nil {
		c.DBPool.Close()
	}
}

func seedDefaultRoles(s *service.PermissionService) {
	s.AddMemoryRole(model.Role{ID: "role-admin", Code: "admin", Name: "Campus Administrator", IsSystemRole: true})
	s.AddMemoryRole(model.Role{ID: "role-hod", Code: "hod", Name: "Head of Department"})
	s.AddMemoryRole(model.Role{ID: "role-faculty", Code: "faculty", Name: "Faculty"})
	s.AddMemoryRole(model.Role{ID: "role-warden", Code: "warden", Name: "Hostel Warden"})
	s.AddMemoryRole(model.Role{ID: "role-canteen", Code: "canteen_manager", Name: "Canteen Manager"})
	s.AddMemoryRole(model.Role{ID: "role-staff", Code: "staff", Name: "Campus Staff"})
	s.AddMemoryRole(model.Role{ID: "role-student", Code: "student", Name: "Student"})
	s.AddMemoryRole(model.Role{ID: "role-contractor", Code: "contractor", Name: "External Contractor"})

	s.AddMemoryScope(model.Scope{Code: "global", Name: "Global", ScopeType: "global"})
	s.AddMemoryScope(model.Scope{Code: "dept:cse", Name: "Computer Science", ScopeType: "department"})
	s.AddMemoryScope(model.Scope{Code: "sec:cse-3a", Name: "Section CSE-3A", ScopeType: "section"})
}

// NewDefaultContainer builds a container using environment variables
func NewDefaultContainer() (*Container, error) {
	dbHost := os.Getenv("POSTGRES_HOST")
	if dbHost == "" {
		dbHost = "localhost"
	}
	dbPort := 5432
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
	redisAddr := os.Getenv("REDIS_ADDR")
	if redisAddr == "" {
		redisAddr = "localhost:6379"
	}

	cfg := ContainerConfig{
		DBHost:          dbHost,
		DBPort:          dbPort,
		DBUser:          dbUser,
		DBPassword:      dbPassword,
		DBName:          dbName,
		RedisAddr:       redisAddr,
		UseMemoryStores: false,
	}

	return NewContainer(cfg)
}
