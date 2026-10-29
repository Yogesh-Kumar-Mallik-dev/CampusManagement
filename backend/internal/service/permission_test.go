package service

import (
	"context"
	"testing"
	"time"

	"campus/backend/internal/model"
)

func TestPermissionHierarchyAndScopes(t *testing.T) {
	svc := NewPermissionService(nil, nil)
	ctx := context.Background()

	// 1. Setup Roles
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
		},
	})

	svc.AddMemoryRole(model.Role{
		Code: "hod",
		Name: "Head of Department",
		Permissions: []model.Permission{
			{Code: "attendance:mark"},
			{Code: "syllabus:approve"},
		},
	})

	svc.AddMemoryRole(model.Role{
		Code: "campus_director",
		Name: "Campus Director",
		Permissions: []model.Permission{
			{Code: "*"}, // Superuser / campus-wide wildcard
		},
	})

	// 2. Setup Scopes (dept:cse -> parent of sec:cse-3a)
	deptID := "dept-cse-id"
	svc.AddMemoryScope(model.Scope{
		BaseSyncModel: model.BaseSyncModel{ID: deptID},
		Code:          "dept:cse",
		Name:          "Computer Science Department",
	})
	svc.AddMemoryScope(model.Scope{
		BaseSyncModel: model.BaseSyncModel{ID: "sec-cse-3a-id"},
		Code:          "sec:cse-3a",
		Name:          "CSE Section 3A",
		ParentScopeID: &deptID,
	})

	// 3. User Aarav (Student) is CR for sec:cse-3a AND President for club:robotics
	aaravID := "user-aarav-uuid"
	_ = svc.AssignRole(ctx, aaravID, "class_rep", "sec:cse-3a", nil)
	_ = svc.AssignRole(ctx, aaravID, "club_president", "club:robotics", nil)

	// Can Aarav mark attendance in his section (sec:cse-3a)? YES
	allowed, reason := svc.Can(ctx, aaravID, "attendance:mark", "sec:cse-3a")
	if !allowed {
		t.Fatalf("expected allowed for sec:cse-3a, got denied: %s", reason)
	}

	// Can Aarav mark attendance in another section (sec:cse-3b)? NO
	allowed, _ = svc.Can(ctx, aaravID, "attendance:mark", "sec:cse-3b")
	if allowed {
		t.Fatalf("expected denied for sec:cse-3b, but was allowed")
	}

	// Can Aarav publish events for club:robotics? YES
	allowed, _ = svc.Can(ctx, aaravID, "club:publish_event", "club:robotics")
	if !allowed {
		t.Fatalf("expected allowed for club:robotics event publish")
	}

	// Can Aarav publish events for club:music? NO
	allowed, _ = svc.Can(ctx, aaravID, "club:publish_event", "club:music")
	if allowed {
		t.Fatalf("expected denied for club:music")
	}

	// 4. Test HOD Hierarchy: Dr. Sharma is HOD for dept:cse
	hodID := "user-dr-sharma-uuid"
	_ = svc.AssignRole(ctx, hodID, "hod", "dept:cse", nil)

	// Can HOD mark/approve attendance in child section sec:cse-3a? YES (Hierarchy coverage)
	allowed, _ = svc.Can(ctx, hodID, "attendance:mark", "sec:cse-3a")
	if !allowed {
		t.Fatalf("expected HOD to have authority over child section sec:cse-3a")
	}

	// 5. Test Expired Temporary Role (e.g. CR for a semester)
	tempStudentID := "user-temp-cr-uuid"
	yesterday := time.Now().UTC().Add(-24 * time.Hour)
	_ = svc.AssignRole(ctx, tempStudentID, "class_rep", "sec:cse-3a", &yesterday)

	allowed, _ = svc.Can(ctx, tempStudentID, "attendance:mark", "sec:cse-3a")
	if allowed {
		t.Fatalf("expected expired role assignment to be denied")
	}

	// 6. Test Campus Director (Global scope)
	directorID := "user-director-uuid"
	_ = svc.AssignRole(ctx, directorID, "campus_director", "global", nil)

	allowed, _ = svc.Can(ctx, directorID, "attendance:mark", "sec:cse-3a")
	if !allowed {
		t.Fatalf("expected campus director with global scope to be allowed anywhere")
	}
}
