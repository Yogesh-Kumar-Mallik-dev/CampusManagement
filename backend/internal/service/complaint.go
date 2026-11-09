package service

import (
	"campus/backend/internal/model"
	"errors"
	"fmt"
	"strings"
	"sync"
	"time"
)

type ComplaintService struct {
	mu         sync.RWMutex
	complaints map[string]model.Complaint
	counter    int
}

func NewComplaintService() *ComplaintService {
	svc := &ComplaintService{
		complaints: make(map[string]model.Complaint),
		counter:    100,
	}
	svc.seedDefaults()
	return svc
}

func (s *ComplaintService) seedDefaults() {
	now := time.Now()

	samples := []model.Complaint{
		{
			BaseSyncModel: model.BaseSyncModel{
				ID:        "cmp-001",
				CreatedAt: now.Add(-48 * time.Hour),
				UpdatedAt: now.Add(-48 * time.Hour),
			},
			Title:           "Water leakage in Aryabhatta Block 2nd floor restroom",
			Description:     "Constant leaking pipe in 2nd floor west-wing bathroom causing water wastage and slippery tiles.",
			Category:        model.ComplaintCategoryHostel,
			Urgency:         model.ComplaintUrgencyHigh,
			IsAnonymous:     true,
			SubmittedBy:     "usr-harish_2025_l_btech_1",
			SubmitterName:   "Anonymous Reporter",
			SubmitterHandle: "anonymous",
			SubmitterRole:   "Anonymous",
			Status:          model.ComplaintStatusInProgress,
			ResolutionRemarks: "Plumbing maintenance team notified and work order issued.",
			ResolvedBy:      "usr-ramesh_2023_emp_1",
		},
		{
			BaseSyncModel: model.BaseSyncModel{
				ID:        "cmp-002",
				CreatedAt: now.Add(-36 * time.Hour),
				UpdatedAt: now.Add(-36 * time.Hour),
			},
			Title:           "Streetlight flickering near Gate 2 walkway",
			Description:     "Main pathway from academic complex to Gate 2 has dark spots due to malfunctioning LED streetlight.",
			Category:        model.ComplaintCategoryCampus,
			Urgency:         model.ComplaintUrgencyMedium,
			IsAnonymous:     true,
			SubmittedBy:     "usr-priya_2024_emp_1",
			SubmitterName:   "Anonymous Reporter",
			SubmitterHandle: "anonymous",
			SubmitterRole:   "Anonymous",
			Status:          model.ComplaintStatusOpen,
		},
		{
			BaseSyncModel: model.BaseSyncModel{
				ID:        "cmp-003",
				CreatedAt: now.Add(-24 * time.Hour),
				UpdatedAt: now.Add(-24 * time.Hour),
			},
			Title:           "Grade calculation discrepancy in CS-301 Midterm Examination",
			Description:     "Question 4 (Dynamic Programming, 10 marks) was marked correct with full points in answer script but recorded as 0 in gradebook portal.",
			Category:        model.ComplaintCategoryStudent,
			Urgency:         model.ComplaintUrgencyHigh,
			IsAnonymous:     false,
			SubmittedBy:     "usr-harish_2025_l_btech_1",
			SubmitterName:   "Harish Kumar",
			SubmitterHandle: "harish_2025_l_btech_1",
			SubmitterRole:   "student",
			Status:          model.ComplaintStatusOpen,
		},
		{
			BaseSyncModel: model.BaseSyncModel{
				ID:        "cmp-004",
				CreatedAt: now.Add(-12 * time.Hour),
				UpdatedAt: now.Add(-12 * time.Hour),
			},
			Title:           "Office AC cooling unit non-functional in Computer Center Room 204",
			Description:     "Temperature exceeds 34C in faculty lab during afternoon lab sessions due to blower motor failure.",
			Category:        model.ComplaintCategoryEmployee,
			Urgency:         model.ComplaintUrgencyMedium,
			IsAnonymous:     false,
			SubmittedBy:     "usr-priya_2024_emp_1",
			SubmitterName:   "Dr. Priya Sharma",
			SubmitterHandle: "priya_2024_emp_1",
			SubmitterRole:   "employee",
			Status:          model.ComplaintStatusInProgress,
			ResolutionRemarks: "HVAC contractor scheduled for compressor overhaul.",
			ResolvedBy:      "usr-ramesh_2023_emp_1",
		},
		{
			BaseSyncModel: model.BaseSyncModel{
				ID:        "cmp-005",
				CreatedAt: now.Add(-6 * time.Hour),
				UpdatedAt: now.Add(-6 * time.Hour),
			},
			Title:           "Commercial gas cylinder unloading area blocked at Central Canteen",
			Description:     "Unloading bay blocked by unauthorized vehicle parking, preventing morning delivery of fuel cylinders.",
			Category:        model.ComplaintCategoryContractor,
			Urgency:         model.ComplaintUrgencyCritical,
			IsAnonymous:     false,
			SubmittedBy:     "usr-mukesh_2025_ext_1",
			SubmitterName:   "Mukesh Verma",
			SubmitterHandle: "mukesh_2025_ext_1",
			SubmitterRole:   "external",
			Status:          model.ComplaintStatusResolved,
			ResolutionRemarks: "Security personnel deployed tow truck and cleared loading dock.",
			ResolvedBy:      "usr-ramesh_2023_emp_1",
			ResolvedAt:      &now,
		},
	}

	for _, c := range samples {
		s.complaints[c.ID] = c
	}
}

func (s *ComplaintService) CreateComplaint(c model.Complaint) (*model.Complaint, error) {
	if err := c.Validate(); err != nil {
		return nil, err
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	s.counter++
	c.ID = fmt.Sprintf("cmp-%d", s.counter)
	now := time.Now()
	c.CreatedAt = now
	c.UpdatedAt = now
	c.Status = model.ComplaintStatusOpen

	// Enforce anonymity values if anonymous
	if c.IsAnonymous {
		c.SubmitterName = "Anonymous Reporter"
		c.SubmitterHandle = "anonymous"
		c.SubmitterRole = "Anonymous"
	}

	s.complaints[c.ID] = c
	res := c
	return &res, nil
}

func (s *ComplaintService) GetComplaint(id, viewerID string) (*model.Complaint, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	c, ok := s.complaints[id]
	if !ok {
		return nil, errors.New("complaint not found")
	}
	res := c.SanitizedForViewer(viewerID)
	return &res, nil
}

func (s *ComplaintService) ListComplaints(category, status, submittedBy, viewerID string, allowedCategories []string) []model.Complaint {
	s.mu.RLock()
	defer s.mu.RUnlock()

	categoryFilter := strings.ToLower(strings.TrimSpace(category))
	statusFilter := strings.ToLower(strings.TrimSpace(status))
	submittedFilter := strings.TrimSpace(submittedBy)

	// Build map of allowed categories if restricted
	allowedMap := make(map[string]bool)
	hasCategoryRestrictions := len(allowedCategories) > 0
	for _, ac := range allowedCategories {
		allowedMap[strings.ToLower(strings.TrimSpace(ac))] = true
	}

	var results []model.Complaint
	for _, c := range s.complaints {
		// Category filter
		if categoryFilter != "" && c.Category != categoryFilter {
			continue
		}
		// Status filter
		if statusFilter != "" && c.Status != statusFilter {
			continue
		}
		// Submitter filter
		if submittedFilter != "" && c.SubmittedBy != submittedFilter {
			continue
		}
		// If officer viewing administrative list and not the submitter, check allowed categories
		if submittedFilter == "" && hasCategoryRestrictions && !allowedMap["*"] && !allowedMap[c.Category] {
			continue
		}

		results = append(results, c.SanitizedForViewer(viewerID))
	}

	return results
}

func (s *ComplaintService) UpdateComplaintStatus(id, newStatus, remarks, resolvedBy string) (*model.Complaint, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	c, ok := s.complaints[id]
	if !ok {
		return nil, errors.New("complaint not found")
	}

	stat := strings.ToLower(strings.TrimSpace(newStatus))
	switch stat {
	case model.ComplaintStatusOpen, model.ComplaintStatusInProgress, model.ComplaintStatusResolved, model.ComplaintStatusRejected:
		c.Status = stat
	default:
		return nil, errors.New("invalid status: " + newStatus)
	}

	c.ResolutionRemarks = strings.TrimSpace(remarks)
	c.ResolvedBy = strings.TrimSpace(resolvedBy)
	now := time.Now()
	c.UpdatedAt = now
	if stat == model.ComplaintStatusResolved || stat == model.ComplaintStatusRejected {
		c.ResolvedAt = &now
	}

	s.complaints[id] = c
	res := c
	return &res, nil
}
