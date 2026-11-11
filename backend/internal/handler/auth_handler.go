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
	permService service.PermissionServiceInterface
}

func NewAuthHandler(permService service.PermissionServiceInterface) *AuthHandler {
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
