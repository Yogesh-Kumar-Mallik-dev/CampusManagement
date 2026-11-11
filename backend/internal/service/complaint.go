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
	if ShouldSeedMockData() {
		svc.seedDefaults()
	}
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
			Title:           "Water leakage in Block 2 Floor 1 restroom",
			Description:     "Constant leaking pipe in Floor 1 Block 2 restroom causing water wastage and slippery tiles.",
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
			Title:               "Grade calculation discrepancy in CS-301 Midterm Examination",
			Description:         "Question 4 (Dynamic Programming, 10 marks) was marked correct with full points in answer script but recorded as 0 in gradebook portal.",
			Category:            model.ComplaintCategoryStudent,
			Urgency:             model.ComplaintUrgencyHigh,
			IsAnonymous:         false,
			SubmittedBy:         "usr-harish_2025_l_btech_1",
			SubmitterName:       "Harish Kumar",
			SubmitterHandle:     "harish_2025_l_btech_1",
			SubmitterRole:       "student",
			Status:              model.ComplaintStatusOpen,
			IsDispute:           true,
			DisputeTargetType:   model.DisputeTargetResult,
			DisputeTargetID:     "CS301-Midterm-2026",
			DisputeEvidence:     "Physical answer sheet shows 10 marks for Q4 Dynamic Programming, but gradebook portal records 0.",
			RequestedResolution: "Grade Recalculation (+10 marks)",
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
		{
			BaseSyncModel: model.BaseSyncModel{
				ID:        "cmp-006",
				CreatedAt: now.Add(-4 * time.Hour),
				UpdatedAt: now.Add(-4 * time.Hour),
			},
			Title:               "Dispute on library overdue late fine for CLRS Algorithms",
			Description:         "Book was deposited in the automated return dropbox prior to 5:00 PM on due date during network downtime.",
			Category:            model.ComplaintCategoryStudent,
			Urgency:             model.ComplaintUrgencyMedium,
			IsAnonymous:         false,
			SubmittedBy:         "usr-harish_2025_l_btech_1",
			SubmitterName:       "Harish Kumar",
			SubmitterHandle:     "harish_2025_l_btech_1",
			SubmitterRole:       "student",
			Status:              model.ComplaintStatusOpen,
			IsDispute:           true,
			DisputeTargetType:   model.DisputeTargetFine,
			DisputeTargetID:     "fine-lib-01",
			DisputeEvidence:     "Circulation desk manual register entry and automated locker check-in slip.",
			RequestedResolution: "Full Fine Waiver (₹50.00)",
		},
		{
			BaseSyncModel: model.BaseSyncModel{
				ID:        "cmp-007",
				CreatedAt: now.Add(-2 * time.Hour),
				UpdatedAt: now.Add(-2 * time.Hour),
			},
			Title:               "Duplicate computer laboratory surcharge on Semester Fee Invoice",
			Description:         "Billed twice for Advanced Computing Lab fee (₹2,500 x 2) on invoice INV-2026-001.",
			Category:            model.ComplaintCategoryStudent,
			Urgency:             model.ComplaintUrgencyHigh,
			IsAnonymous:         false,
			SubmittedBy:         "usr-harish_2025_l_btech_1",
			SubmitterName:       "Harish Kumar",
			SubmitterHandle:     "harish_2025_l_btech_1",
			SubmitterRole:       "student",
			Status:              model.ComplaintStatusInProgress,
			ResolutionRemarks:   "Treasury audit confirmed duplicate debit; credit note adjustment being processed.",
			ResolvedBy:          "usr-ramesh_2023_emp_1",
			IsDispute:           true,
			DisputeTargetType:   model.DisputeTargetFee,
			DisputeTargetID:     "INV-2026-001",
			DisputeEvidence:     "Itemized invoice breakdown reflects duplicate item code LAB-CS3 under fee schedule.",
			RequestedResolution: "Fee Correction / Invoice Adjustment (-₹2,500)",
		},
		{
			BaseSyncModel: model.BaseSyncModel{
				ID:        "cmp-008",
				CreatedAt: now.Add(-1 * time.Hour),
				UpdatedAt: now.Add(-1 * time.Hour),
			},
			Title:               "Omission of approved conference travel allowance from October salary",
			Description:         "Approved travel reimbursement ref DEAN/TR/2026/89 was not reconciled in October salary slip.",
			Category:            model.ComplaintCategoryEmployee,
			Urgency:             model.ComplaintUrgencyHigh,
			IsAnonymous:         false,
			SubmittedBy:         "usr-priya_2024_emp_1",
			SubmitterName:       "Dr. Priya Sharma",
			SubmitterHandle:     "priya_2024_emp_1",
			SubmitterRole:       "employee",
			Status:              model.ComplaintStatusOpen,
			IsDispute:           true,
			DisputeTargetType:   model.DisputeTargetPayroll,
			DisputeTargetID:     "PAYROLL-2026-10",
			DisputeEvidence:     "Dean approval memo DEAN/TR/2026/89 dated Oct 12 and boarding ticket receipts.",
			RequestedResolution: "Credit of ₹12,000 in supplementary payroll cycle",
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

// RaiseDispute formalizes a student or staff contention leveraging the complaint pipeline.
func (s *ComplaintService) RaiseDispute(c model.Complaint) (*model.Complaint, error) {
	c.IsDispute = true
	return s.CreateComplaint(c)
}

// ListDisputes returns formal disputes filtered by target type, status, and permissions.
func (s *ComplaintService) ListDisputes(targetType, status, submittedBy, viewerID string, allowedCategories []string) []model.Complaint {
	s.mu.RLock()
	defer s.mu.RUnlock()

	targetTypeFilter := strings.ToLower(strings.TrimSpace(targetType))
	statusFilter := strings.ToLower(strings.TrimSpace(status))
	submittedFilter := strings.TrimSpace(submittedBy)

	allowedMap := make(map[string]bool)
	hasCategoryRestrictions := len(allowedCategories) > 0
	for _, ac := range allowedCategories {
		allowedMap[strings.ToLower(strings.TrimSpace(ac))] = true
	}

	var results []model.Complaint
	for _, c := range s.complaints {
		if !c.IsDispute {
			continue
		}
		if targetTypeFilter != "" && c.DisputeTargetType != targetTypeFilter {
			continue
		}
		if statusFilter != "" && c.Status != statusFilter {
			continue
		}
		if submittedFilter != "" && c.SubmittedBy != submittedFilter {
			continue
		}
		if submittedFilter == "" && hasCategoryRestrictions && !allowedMap["*"] && !allowedMap[c.Category] {
			continue
		}
		results = append(results, c.SanitizedForViewer(viewerID))
	}
	return results
}
