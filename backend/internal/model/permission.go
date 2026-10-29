package model

import "time"

// Scope represents an organizational or physical boundary
type Scope struct {
	BaseSyncModel
	Code          string  `json:"code"`       // e.g. 'global', 'dept:cse', 'sec:cse-3a', 'club:robotics'
	Name          string  `json:"name"`       // 'Computer Science Department'
	ScopeType     string  `json:"scope_type"` // 'department', 'section', 'hostel', 'club'
	ParentScopeID *string `json:"parent_scope_id,omitempty"`
}

// Permission represents an atomic Action:Resource right
type Permission struct {
	ID          string `json:"id"`
	Code        string `json:"code"`        // e.g. 'attendance:mark', 'notice:publish'
	Description string `json:"description"`
	Module      string `json:"module"`      // 'academic', 'hostel', 'security'
}

// Role is a collection of permissions
type Role struct {
	ID           string       `json:"id"`
	Code         string       `json:"code"` // e.g. 'class_rep', 'hod', 'warden'
	Name         string       `json:"name"`
	Description  string       `json:"description"`
	IsSystemRole bool         `json:"is_system_role"`
	Permissions  []Permission `json:"permissions,omitempty"`
}

// UserRoleAssignment connects User <-> Role <-> Scope
type UserRoleAssignment struct {
	BaseSyncModel
	UserID     string     `json:"user_id"`
	RoleID     string     `json:"role_id"`
	RoleCode   string     `json:"role_code"`
	RoleName   string     `json:"role_name"`
	ScopeID    *string    `json:"scope_id,omitempty"`
	ScopeCode  string     `json:"scope_code,omitempty"` // 'global' if null
	ValidFrom  time.Time  `json:"valid_from"`
	ValidUntil *time.Time `json:"valid_until,omitempty"`
	IsActive   bool       `json:"is_active"`
}

// PermissionCheckRequest checks if a user has a specific permission in a scope
type PermissionCheckRequest struct {
	UserID         string `json:"user_id"`
	PermissionCode string `json:"permission_code"` // e.g. 'attendance:mark'
	ScopeCode      string `json:"scope_code"`      // e.g. 'sec:cse-3a'
}

type PermissionCheckResponse struct {
	Allowed   bool   `json:"allowed"`
	Reason    string `json:"reason,omitempty"`
	ScopeUsed string `json:"scope_used,omitempty"`
}
