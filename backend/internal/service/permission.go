package service

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"

	"campus/backend/internal/cache"
	"campus/backend/internal/model"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PermissionService struct {
	db           *pgxpool.Pool
	cache        *cache.ResilientManager
	mu           sync.RWMutex
	memAssigns   map[string][]model.UserRoleAssignment // Fallback for testing/memory
	memRoles     map[string]model.Role
	memScopes    map[string]model.Scope
}

func NewPermissionService(db *pgxpool.Pool, cache *cache.ResilientManager) *PermissionService {
	return &PermissionService{
		db:         db,
		cache:      cache,
		memAssigns: make(map[string][]model.UserRoleAssignment),
		memRoles:   make(map[string]model.Role),
		memScopes:  make(map[string]model.Scope),
	}
}

// AddMemoryRole registers a role and its permissions for in-memory use
func (s *PermissionService) AddMemoryRole(role model.Role) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.memRoles[role.Code] = role
}

// AddMemoryScope registers a scope and its parent hierarchy
func (s *PermissionService) AddMemoryScope(scope model.Scope) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.memScopes[scope.Code] = scope
}

// AssignRole grants a role to a user within a specific scope
func (s *PermissionService) AssignRole(ctx context.Context, userID, roleCode, scopeCode string, validUntil *time.Time) error {
	if ctx == nil {
		ctx = context.Background()
	}
	s.mu.Lock()
	defer s.mu.Unlock()

	roleName := roleCode
	if r, exists := s.memRoles[roleCode]; exists && r.Name != "" {
		roleName = r.Name
	}

	assign := model.UserRoleAssignment{
		BaseSyncModel: model.BaseSyncModel{
			ID:        fmt.Sprintf("assign-%d", time.Now().UnixNano()),
			CreatedAt: time.Now().UTC(),
			UpdatedAt: time.Now().UTC(),
		},
		UserID:     userID,
		RoleCode:   roleCode,
		RoleName:   roleName,
		ScopeCode:  scopeCode,
		ValidFrom:  time.Now().UTC(),
		ValidUntil: validUntil,
		IsActive:   true,
	}

	s.memAssigns[userID] = append(s.memAssigns[userID], assign)

	// Invalidate cache for this user
	if s.cache != nil {
		_, _ = s.cache.FetchOrCompute(ctx, "perm:"+userID, 0, func(ctx context.Context) ([]byte, error) {
			return nil, nil
		})
	}

	return nil
}

// RevokeAllUserRoles revokes all role assignments for a discontinued or suspended user
func (s *PermissionService) RevokeAllUserRoles(ctx context.Context, userID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	assignments, exists := s.memAssigns[userID]
	if exists {
		now := time.Now().UTC()
		for i := range assignments {
			assignments[i].IsActive = false
			assignments[i].UpdatedAt = now
		}
		s.memAssigns[userID] = assignments
	}

	if s.cache != nil {
		_, _ = s.cache.FetchOrCompute(ctx, "perm:"+userID, 0, func(ctx context.Context) ([]byte, error) {
			return nil, nil
		})
	}
	return nil
}

// GetUserRoles returns all role assignments for a given user
func (s *PermissionService) GetUserRoles(userID string) []model.UserRoleAssignment {
	s.mu.RLock()
	defer s.mu.RUnlock()

	assignments, exists := s.memAssigns[userID]
	if !exists {
		return []model.UserRoleAssignment{}
	}
	res := make([]model.UserRoleAssignment, len(assignments))
	copy(res, assignments)
	return res
}

// GetUserPermissions returns all deduplicated permission codes granted to the user across their active roles
func (s *PermissionService) GetUserPermissions(userID string) []string {
	s.mu.RLock()
	defer s.mu.RUnlock()

	assignments, exists := s.memAssigns[userID]
	if !exists || len(assignments) == 0 {
		return []string{}
	}

	now := time.Now().UTC()
	permMap := make(map[string]bool)

	for _, assign := range assignments {
		if !assign.IsActive {
			continue
		}
		if assign.ValidUntil != nil && now.After(*assign.ValidUntil) {
			continue
		}
		role, roleExists := s.memRoles[assign.RoleCode]
		if !roleExists {
			lower := strings.ToLower(assign.RoleCode)
			if strings.Contains(lower, "president") {
				role, roleExists = s.memRoles["club_president"]
			} else if strings.Contains(lower, "coordinator") {
				role, roleExists = s.memRoles["coordinator"]
			} else if strings.Contains(lower, "library") {
				role, roleExists = s.memRoles["library_incharge"]
			} else if strings.Contains(lower, "representative") || strings.Contains(lower, "class_rep") {
				role, roleExists = s.memRoles["class_representative"]
			}
		}
		if !roleExists {
			continue
		}
		for _, perm := range role.Permissions {
			permMap[perm.Code] = true
		}
	}

	res := make([]string, 0, len(permMap))
	for code := range permMap {
		res = append(res, code)
	}
	return res
}

// Can evaluates if a user can execute `permissionCode` within `requestedScope`
func (s *PermissionService) Can(ctx context.Context, userID, permissionCode, requestedScope string) (bool, string) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	assignments, exists := s.memAssigns[userID]
	if !exists || len(assignments) == 0 {
		return false, "User has no active role assignments"
	}

	now := time.Now().UTC()

	for _, assign := range assignments {
		if !assign.IsActive {
			continue
		}
		if assign.ValidUntil != nil && now.After(*assign.ValidUntil) {
			continue // expired temporary role
		}

		role, roleExists := s.memRoles[assign.RoleCode]
		if !roleExists {
			lower := strings.ToLower(assign.RoleCode)
			if strings.Contains(lower, "president") {
				role, roleExists = s.memRoles["club_president"]
			} else if strings.Contains(lower, "coordinator") {
				role, roleExists = s.memRoles["coordinator"]
			} else if strings.Contains(lower, "library") {
				role, roleExists = s.memRoles["library_incharge"]
			} else if strings.Contains(lower, "representative") || strings.Contains(lower, "class_rep") {
				role, roleExists = s.memRoles["class_representative"]
			}
		}
		if !roleExists {
			continue
		}

		// Check if this role has the requested permission
		hasPermission := false
		for _, perm := range role.Permissions {
			if perm.Code == permissionCode || perm.Code == "*" {
				hasPermission = true
				break
			}
		}

		if !hasPermission {
			continue
		}

		// Check scope hierarchy
		if s.isScopeCovered(assign.ScopeCode, requestedScope) {
			return true, fmt.Sprintf("Allowed by role '%s' scoped to '%s'", assign.RoleCode, assign.ScopeCode)
		}
	}

	return false, fmt.Sprintf("Permission '%s' denied in scope '%s'", permissionCode, requestedScope)
}

// isScopeCovered determines if grantedScope covers requestedScope
// Rules:
// 1. 'global' or '' covers EVERYTHING.
// 2. Exact match (e.g., 'sec:cse-3a' covers 'sec:cse-3a').
// 3. Parent hierarchy: 'dept:cse' covers 'sec:cse-3a' and 'lab:cse-iot'.
func (s *PermissionService) isScopeCovered(grantedScope, requestedScope string) bool {
	if grantedScope == "global" || grantedScope == "" {
		return true // Campus-wide authority (e.g. Dean, Principal)
	}
	if grantedScope == requestedScope {
		return true // Exact scope match
	}

	// Hierarchy check: Does requestedScope belong to grantedScope?
	currCode := requestedScope
	for currCode != "" {
		scope, exists := s.memScopes[currCode]
		if !exists || scope.ParentScopeID == nil {
			break
		}
		// find parent scope code
		foundParent := false
		for _, parent := range s.memScopes {
			if scope.ParentScopeID != nil && *scope.ParentScopeID == parent.ID {
				if parent.Code == grantedScope {
					return true
				}
				currCode = parent.Code
				foundParent = true
				break
			}
		}
		if !foundParent {
			break
		}
	}

	// Simple colon prefix convention fallback:
	// If granted is 'dept:cse' and requested is 'dept:cse:sec-a'
	if strings.HasPrefix(requestedScope, grantedScope+":") {
		return true
	}

	return false
}
