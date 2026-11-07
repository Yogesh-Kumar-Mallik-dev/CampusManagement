package handler

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

type AuthHandler struct {
	permService *service.PermissionService
}

func NewAuthHandler(permService *service.PermissionService) *AuthHandler {
	return &AuthHandler{
		permService: permService,
	}
}

type LoginRequest struct {
	Identifier string `json:"identifier"` // campus handle or email
	Password   string `json:"password"`
}

type LoginResponse struct {
	Token         string                     `json:"token"`
	User          model.User                 `json:"user"`
	Scopes        []string                   `json:"scopes"`
	AssignedRoles []model.UserRoleAssignment `json:"assigned_roles,omitempty"`
	Permissions   []string                   `json:"permissions,omitempty"`
	ExpiresAt     time.Time                  `json:"expires_at"`
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
		return
	}

	cleanID := strings.TrimSpace(strings.ToLower(req.Identifier))
	if cleanID == "" {
		http.Error(w, "Identifier (handle or email) is required", http.StatusBadRequest)
		return
	}

	// Institutional default accounts
	var user model.User
	var scopes []string
	now := time.Now().UTC()

	switch cleanID {
	case "harish_2025_l_btech_1", "harish_2025_l_btech_1@campus.edu":
		user = model.User{
			BaseSyncModel: model.BaseSyncModel{
				ID:        "usr-harish_2025_l_btech_1",
				CreatedAt: now,
				UpdatedAt: now,
			},
			CampusHandle: "harish_2025_l_btech_1",
			FirstName:    "Harish",
			LastName:     "Kumar",
			Email:        "harish_2025_l_btech_1@campus.edu",
			Archetype:    model.ArchetypeStudent,
			IsActive:     true,
		}
		scopes = []string{"global", "sec:cse-3a", "club:robotics"}

	case "priya_2024_emp_1", "priya_2024_emp_1@campus.edu":
		user = model.User{
			BaseSyncModel: model.BaseSyncModel{
				ID:        "usr-priya_2024_emp_1",
				CreatedAt: now,
				UpdatedAt: now,
			},
			CampusHandle: "priya_2024_emp_1",
			FirstName:    "Dr. Priya",
			LastName:     "Nair",
			Email:        "priya_2024_emp_1@campus.edu",
			Archetype:    model.ArchetypeEmployee,
			IsActive:     true,
		}
		scopes = []string{"global", "dept:cse", "sec:cse-3a", "unit:student_affairs"}

	case "ramesh_2023_emp_1", "ramesh_2023_emp_1@campus.edu":
		user = model.User{
			BaseSyncModel: model.BaseSyncModel{
				ID:        "usr-ramesh_2023_emp_1",
				CreatedAt: now,
				UpdatedAt: now,
			},
			CampusHandle: "ramesh_2023_emp_1",
			FirstName:    "Ramesh",
			LastName:     "Singh",
			Email:        "ramesh_2023_emp_1@campus.edu",
			Archetype:    model.ArchetypeEmployee,
			IsActive:     true,
		}
		scopes = []string{"global", "unit:security", "facility:gate-1"}

	case "campus_admin", "admin", "admin@campus.edu", "director", "director@campus.edu":
		user = model.User{
			BaseSyncModel: model.BaseSyncModel{
				ID:        "usr-campus_admin",
				CreatedAt: now,
				UpdatedAt: now,
			},
			CampusHandle: "campus_admin",
			FirstName:    "Campus",
			LastName:     "Administrator",
			Email:        "admin@campus.edu",
			Archetype:    model.ArchetypeEmployee,
			IsActive:     true,
		}
		scopes = []string{"global"}

	case "mukesh_2025_ext_1", "mukesh_2025_ext_1@campus.edu":
		user = model.User{
			BaseSyncModel: model.BaseSyncModel{
				ID:        "usr-mukesh_2025_ext_1",
				CreatedAt: now,
				UpdatedAt: now,
			},
			CampusHandle: "mukesh_2025_ext_1",
			FirstName:    "Mukesh",
			LastName:     "Verma",
			Email:        "mukesh_2025_ext_1@campus.edu",
			Archetype:    model.ArchetypeExternal,
			IsActive:     true,
		}
		scopes = []string{"gate:main", "building:canteen"}

	default:
		// Generic fallback for any canonical format {name}_{year}_...
		user = model.User{
			BaseSyncModel: model.BaseSyncModel{
				ID:        "usr-" + cleanID,
				CreatedAt: now,
				UpdatedAt: now,
			},
			CampusHandle: cleanID,
			FirstName:    strings.Title(strings.Split(cleanID, "_")[0]),
			LastName:     "Member",
			Email:        cleanID + "@campus.edu",
			Archetype:    model.ArchetypeStudent,
			IsActive:     true,
		}
		scopes = []string{"global", "sec:cse-3a"}
	}

	var assignedRoles []model.UserRoleAssignment
	var permissions []string
	if h.permService != nil {
		assignedRoles = h.permService.GetUserRoles(user.ID)
		permissions = h.permService.GetUserPermissions(user.ID)
	}

	resp := LoginResponse{
		Token:         "tok_" + user.CampusHandle + "_" + time.Now().Format("20060102150405"),
		User:          user,
		Scopes:        scopes,
		AssignedRoles: assignedRoles,
		Permissions:   permissions,
		ExpiresAt:     now.Add(24 * time.Hour),
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}
