package model

import (
	"errors"
	"strings"
	"time"
)

// Complaint categories
const (
	ComplaintCategoryStudent    = "student"
	ComplaintCategoryEmployee   = "employee"
	ComplaintCategoryContractor = "contractor"
	ComplaintCategoryCampus     = "campus"
	ComplaintCategoryHostel     = "hostel"
)

// Complaint statuses
const (
	ComplaintStatusOpen       = "open"
	ComplaintStatusInProgress = "in_progress"
	ComplaintStatusResolved   = "resolved"
	ComplaintStatusRejected   = "rejected"
)

// Complaint urgencies
const (
	ComplaintUrgencyLow      = "low"
	ComplaintUrgencyMedium   = "medium"
	ComplaintUrgencyHigh     = "high"
	ComplaintUrgencyCritical = "critical"
)

type Complaint struct {
	BaseSyncModel
	Title             string     `json:"title"`
	Description       string     `json:"description"`
	Category          string     `json:"category"` // student, employee, contractor, campus, hostel
	Urgency           string     `json:"urgency"`  // low, medium, high, critical
	IsAnonymous       bool       `json:"is_anonymous"`
	SubmittedBy       string     `json:"submitted_by"`     // User ID
	SubmitterName     string     `json:"submitter_name"`   // Masked if anonymous
	SubmitterHandle   string     `json:"submitter_handle"` // Masked if anonymous
	SubmitterRole     string     `json:"submitter_role"`   // Masked if anonymous
	Status            string     `json:"status"`           // open, in_progress, resolved, rejected
	ResolutionRemarks string     `json:"resolution_remarks,omitempty"`
	ResolvedBy        string     `json:"resolved_by,omitempty"`
	ResolvedAt        *time.Time `json:"resolved_at,omitempty"`
}

// SupportsAnonymous checks whether anonymous reporting is supported for the given category.
// Campus infrastructure and Hostel grievances allow anonymous filing.
// Student academic disputes, Employee workplace/payroll grievances, and Contractor vendor claims
// require verified identity.
func SupportsAnonymous(category string) bool {
	cat := strings.ToLower(strings.TrimSpace(category))
	switch cat {
	case ComplaintCategoryCampus, ComplaintCategoryHostel:
		return true
	case ComplaintCategoryStudent, ComplaintCategoryEmployee, ComplaintCategoryContractor:
		return false
	default:
		return false
	}
}

// Validate ensures category, urgency, status, and anonymity rules are respected.
func (c *Complaint) Validate() error {
	if strings.TrimSpace(c.Title) == "" {
		return errors.New("complaint title is required")
	}
	if strings.TrimSpace(c.Description) == "" {
		return errors.New("complaint description is required")
	}

	cat := strings.ToLower(strings.TrimSpace(c.Category))
	switch cat {
	case ComplaintCategoryStudent, ComplaintCategoryEmployee, ComplaintCategoryContractor, ComplaintCategoryCampus, ComplaintCategoryHostel:
		c.Category = cat
	default:
		return errors.New("invalid complaint category: " + c.Category)
	}

	if c.IsAnonymous && !SupportsAnonymous(c.Category) {
		return errors.New("anonymous complaints are not supported for category: " + c.Category)
	}

	urg := strings.ToLower(strings.TrimSpace(c.Urgency))
	if urg == "" {
		urg = ComplaintUrgencyMedium
	}
	switch urg {
	case ComplaintUrgencyLow, ComplaintUrgencyMedium, ComplaintUrgencyHigh, ComplaintUrgencyCritical:
		c.Urgency = urg
	default:
		c.Urgency = ComplaintUrgencyMedium
	}

	stat := strings.ToLower(strings.TrimSpace(c.Status))
	if stat == "" {
		stat = ComplaintStatusOpen
	}
	switch stat {
	case ComplaintStatusOpen, ComplaintStatusInProgress, ComplaintStatusResolved, ComplaintStatusRejected:
		c.Status = stat
	default:
		c.Status = ComplaintStatusOpen
	}

	return nil
}

// SanitizedForViewer returns a copy with submitter identities redacted if anonymous
// and the viewer is not the submitter.
func (c Complaint) SanitizedForViewer(viewerID string) Complaint {
	if c.IsAnonymous {
		c.SubmitterName = "Anonymous Reporter"
		c.SubmitterHandle = "anonymous"
		c.SubmitterRole = "Anonymous"
		if viewerID == "" || viewerID != c.SubmittedBy {
			c.SubmittedBy = "anonymous"
		}
	}
	return c
}
