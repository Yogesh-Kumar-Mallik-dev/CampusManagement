package idgen

import (
	"context"
	"sync"
	"testing"
)

func TestIDServiceGeneration(t *testing.T) {
	svc := NewIDService(nil) // in-memory mode
	ctx := context.Background()

	// 1. Student tests (e.g. Harish 2025 lateral btech)
	h1, err := svc.NextStudentID(ctx, "Harish", 2025, "lateral", "btech")
	if err != nil || h1 != "harish_2025_l_btech_1" {
		t.Fatalf("expected harish_2025_l_btech_1, got %s, err: %v", h1, err)
	}

	h2, err := svc.NextStudentID(ctx, "Harish", 2025, "lateral", "btech")
	if err != nil || h2 != "harish_2025_l_btech_2" {
		t.Fatalf("expected harish_2025_l_btech_2, got %s, err: %v", h2, err)
	}

	h3, err := svc.NextStudentID(ctx, "Harish", 2025, "lateral", "btech")
	if err != nil || h3 != "harish_2025_l_btech_3" {
		t.Fatalf("expected harish_2025_l_btech_3, got %s, err: %v", h3, err)
	}

	// 2. Regular student
	r1, err := svc.NextStudentID(ctx, "Rahul Sharma", 2026, "regular", "btech")
	if err != nil || r1 != "rahulsharma_2026_r_btech_1" {
		t.Fatalf("expected rahulsharma_2026_r_btech_1, got %s, err: %v", r1, err)
	}

	// 3. Employee tests (Unified for faculty and staff)
	e1, err := svc.NextEmployeeID(ctx, "Priya", 2024)
	if err != nil || e1 != "priya_2024_emp_1" {
		t.Fatalf("expected priya_2024_emp_1, got %s, err: %v", e1, err)
	}

	e2, err := svc.NextEmployeeID(ctx, "Priya", 2024)
	if err != nil || e2 != "priya_2024_emp_2" {
		t.Fatalf("expected priya_2024_emp_2, got %s, err: %v", e2, err)
	}

	// Ramesh (Staff member) gets the same stable employee handle
	s1, err := svc.NextEmployeeID(ctx, "Ramesh", 2023)
	if err != nil || s1 != "ramesh_2023_emp_1" {
		t.Fatalf("expected ramesh_2023_emp_1, got %s, err: %v", s1, err)
	}

	// 4. Contractor / External tests (Immune to vendor contract swaps)
	c1, err := svc.NextExternalID(ctx, "Mukesh", 2025)
	if err != nil || c1 != "mukesh_2025_ext_1" {
		t.Fatalf("expected mukesh_2025_ext_1, got %s, err: %v", c1, err)
	}
}

func TestIDServiceConcurrency(t *testing.T) {
	svc := NewIDService(nil)
	ctx := context.Background()

	var wg sync.WaitGroup
	count := 50
	results := make(chan string, count)

	for i := 0; i < count; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			id, err := svc.NextStudentID(ctx, "Harish", 2025, "lateral", "btech")
			if err == nil {
				results <- id
			}
		}()
	}

	wg.Wait()
	close(results)

	unique := make(map[string]bool)
	for id := range results {
		if unique[id] {
			t.Fatalf("collision detected for id: %s", id)
		}
		unique[id] = true
	}

	if len(unique) != count {
		t.Fatalf("expected %d unique IDs, got %d", count, len(unique))
	}
}
