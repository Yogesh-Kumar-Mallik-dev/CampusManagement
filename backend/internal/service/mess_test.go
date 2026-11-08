package service

import (
	"testing"

	"campus/backend/internal/model"
)

func TestMessTimetableSundayScheduleAndWeekMeals(t *testing.T) {
	svc := NewMessService(nil, nil)
	meals := svc.GetWeeklyTimetable()

	if len(meals) != 20 {
		// 6 days * 3 meals = 18 meals; Sunday = 2 meals (Brunch + Dinner); Total = 20 meals
		t.Fatalf("expected 20 meals across the week (6x3 + 2 on Sunday), got %d", len(meals))
	}

	sundayMeals := 0
	hasSundayBrunch := false
	hasSundayBreakfast := false
	hasSundayLunch := false
	hasSundayDinner := false

	for _, m := range meals {
		if m.DayOfWeek == "sunday" {
			sundayMeals++
			if m.MealType == model.MealBrunch {
				hasSundayBrunch = true
			}
			if m.MealType == model.MealBreakfast {
				hasSundayBreakfast = true
			}
			if m.MealType == model.MealLunch {
				hasSundayLunch = true
			}
			if m.MealType == model.MealDinner {
				hasSundayDinner = true
			}
		}
	}

	if sundayMeals != 2 {
		t.Errorf("expected 2 Sunday meals, got %d", sundayMeals)
	}
	if !hasSundayBrunch {
		t.Errorf("expected Sunday to provide Brunch instead of breakfast and lunch")
	}
	if !hasSundayDinner {
		t.Errorf("expected Sunday to have Dinner")
	}
	if hasSundayBreakfast || hasSundayLunch {
		t.Errorf("Sunday must not have separate Breakfast or Lunch slots (Brunch replaces both)")
	}

	// Verify Sunday schedule model validation
	if err := model.ValidateMealForDay("sunday", model.MealBreakfast); err == nil {
		t.Errorf("expected error scheduling Breakfast on Sunday")
	}
	if err := model.ValidateMealForDay("sunday", model.MealLunch); err == nil {
		t.Errorf("expected error scheduling Lunch on Sunday")
	}
	if err := model.ValidateMealForDay("sunday", model.MealBrunch); err != nil {
		t.Errorf("unexpected error scheduling Brunch on Sunday: %v", err)
	}

	// Verify Monday-Saturday schedule: 3 meals, no brunch
	days := []string{"monday", "tuesday", "wednesday", "thursday", "friday", "saturday"}
	for _, day := range days {
		if err := model.ValidateMealForDay(day, model.MealBrunch); err == nil {
			t.Errorf("expected error scheduling Brunch on %s (brunch is Sunday only)", day)
		}
		if err := model.ValidateMealForDay(day, model.MealBreakfast); err != nil {
			t.Errorf("unexpected error scheduling Breakfast on %s: %v", day, err)
		}
		if err := model.ValidateMealForDay(day, model.MealLunch); err != nil {
			t.Errorf("unexpected error scheduling Lunch on %s: %v", day, err)
		}
		if err := model.ValidateMealForDay(day, model.MealDinner); err != nil {
			t.Errorf("unexpected error scheduling Dinner on %s: %v", day, err)
		}
	}
}

func TestMessRatingSystemAndCompulsoryMessageRules(t *testing.T) {
	svc := NewMessService(nil, nil)

	// Test 1: Very Poor rating WITHOUT message -> MUST FAIL (Compulsory)
	_, err := svc.SubmitRating(SubmitRatingRequest{
		MealID:       "meal-monday-lunch",
		UserID:       "u-student-1",
		UserName:     "Student Test",
		CampusHandle: "student_test_1",
		Rating:       model.RatingVeryPoor,
		Message:      "   ", // empty / whitespace
	})
	if err == nil {
		t.Errorf("expected error: feedback message must be compulsory for Very Poor rating")
	}

	// Test 2: Poor rating WITHOUT message -> MUST FAIL (Compulsory)
	_, err = svc.SubmitRating(SubmitRatingRequest{
		MealID:       "meal-monday-lunch",
		UserID:       "u-student-1",
		UserName:     "Student Test",
		CampusHandle: "student_test_1",
		Rating:       model.RatingPoor,
		Message:      "",
	})
	if err == nil {
		t.Errorf("expected error: feedback message must be compulsory for Poor rating")
	}

	// Test 3: Average rating WITHOUT message -> MUST FAIL (Compulsory)
	_, err = svc.SubmitRating(SubmitRatingRequest{
		MealID:       "meal-monday-lunch",
		UserID:       "u-student-1",
		UserName:     "Student Test",
		CampusHandle: "student_test_1",
		Rating:       model.RatingAverage,
		Message:      "",
	})
	if err == nil {
		t.Errorf("expected error: feedback message must be compulsory for Average rating")
	}

	// Test 4: Average rating WITH message -> SUCCEEDS
	recAvg, err := svc.SubmitRating(SubmitRatingRequest{
		MealID:       "meal-monday-lunch",
		UserID:       "u-student-1",
		UserName:     "Student Test",
		CampusHandle: "student_test_1",
		Rating:       model.RatingAverage,
		Message:      "Rice was adequate but curry was lukewarm.",
	})
	if err != nil {
		t.Fatalf("unexpected error submitting Average rating with compulsory message: %v", err)
	}
	if recAvg.Message != "Rice was adequate but curry was lukewarm." {
		t.Errorf("message not persisted properly: %s", recAvg.Message)
	}

	// Test 5: Good rating WITHOUT message -> SUCCEEDS (Optional)
	recGood, err := svc.SubmitRating(SubmitRatingRequest{
		MealID:       "meal-monday-dinner",
		UserID:       "u-student-2",
		UserName:     "Student Good",
		CampusHandle: "student_good_2",
		Rating:       model.RatingGood,
		Message:      "", // optional
	})
	if err != nil {
		t.Fatalf("unexpected error submitting Good rating with empty message: %v", err)
	}
	if recGood.Rating != model.RatingGood {
		t.Errorf("expected Good rating, got %s", recGood.Rating)
	}

	// Test 6: Very Good rating WITHOUT message -> SUCCEEDS (Optional)
	recVGood, err := svc.SubmitRating(SubmitRatingRequest{
		MealID:       "meal-sunday-brunch",
		UserID:       "u-student-3",
		UserName:     "Student VGood",
		CampusHandle: "student_vgood_3",
		Rating:       model.RatingVeryGood,
		Message:      "",
	})
	if err != nil {
		t.Fatalf("unexpected error submitting Very Good rating with empty message: %v", err)
	}
	if recVGood.MealType != model.MealBrunch {
		t.Errorf("expected Sunday Brunch meal type, got %s", recVGood.MealType)
	}

	// Test 7: Abstained rating WITHOUT message -> SUCCEEDS (Optional)
	recAbstain, err := svc.SubmitRating(SubmitRatingRequest{
		MealID:       "meal-sunday-brunch",
		UserID:       "u-student-4",
		UserName:     "Student Abstain",
		CampusHandle: "student_abstain_4",
		Rating:       model.RatingAbstained,
		Message:      "",
	})
	if err != nil {
		t.Fatalf("unexpected error submitting Abstained rating: %v", err)
	}
	if recAbstain.Rating != model.RatingAbstained {
		t.Errorf("expected Abstained rating, got %s", recAbstain.Rating)
	}

	// Test 8: Verify report aggregation and message listing
	report := svc.GetRatingsReport("", "")
	if report.TotalRatings < 6 {
		t.Errorf("expected at least 6 ratings, got %d", report.TotalRatings)
	}
	if report.AverageScore < 1.0 || report.AverageScore > 5.0 {
		t.Errorf("average score out of valid bounds [1.0, 5.0]: %f", report.AverageScore)
	}
	if len(report.RecentMessages) == 0 {
		t.Errorf("expected feedback messages in report")
	}
}
