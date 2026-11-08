package model

import (
	"fmt"
	"strings"
	"time"
)

// MealType represents the meal slot.
// On Monday-Saturday: 'breakfast', 'lunch', 'dinner'.
// On Sunday: 'brunch', 'dinner' ('brunch' replaces breakfast and lunch).
type MealType string

const (
	MealBreakfast MealType = "breakfast"
	MealLunch     MealType = "lunch"
	MealDinner    MealType = "dinner"
	MealBrunch    MealType = "brunch"
)

// RatingValue represents student rating sentiment for mess meals.
type RatingValue string

const (
	RatingVeryPoor  RatingValue = "very_poor"
	RatingPoor      RatingValue = "poor"
	RatingAverage   RatingValue = "average"
	RatingGood      RatingValue = "good"
	RatingVeryGood  RatingValue = "very_good"
	RatingAbstained RatingValue = "abstained"
)

// MessMeal represents a scheduled meal in the weekly mess timetable.
type MessMeal struct {
	ID          string   `json:"id"`
	DayOfWeek   string   `json:"day_of_week"` // 'monday' ... 'sunday'
	MealType    MealType `json:"meal_type"`   // 'breakfast', 'lunch', 'dinner', 'brunch'
	StartTime   string   `json:"start_time"`  // "07:30", "10:00", "12:30", "19:30"
	EndTime     string   `json:"end_time"`    // "09:30", "13:00", "14:30", "21:30"
	Title       string   `json:"title"`
	MenuSummary string   `json:"menu_summary"`
	Items       []string `json:"items"`
}

// MessRating represents a student's review and feedback message for a meal.
type MessRating struct {
	ID           string      `json:"id"`
	MealID       string      `json:"meal_id"`
	DayOfWeek    string      `json:"day_of_week"`
	MealType     MealType    `json:"meal_type"`
	UserID       string      `json:"user_id"`
	UserName     string      `json:"user_name"`
	CampusHandle string      `json:"campus_handle"`
	Rating       RatingValue `json:"rating"`
	Message      string      `json:"message"` // compulsory for very_poor, poor, average; optional for rest
	CreatedAt    time.Time   `json:"created_at"`
}

// MessReportSummary provides aggregate analytics for mess operations.
type MessReportSummary struct {
	TotalRatings     int                    `json:"total_ratings"`
	AverageScore     float64                `json:"average_score"` // out of 5.0 (excluding abstained)
	RatingCounts     map[RatingValue]int    `json:"rating_counts"`
	RecentMessages   []MessRating           `json:"recent_messages"`
	SundayScheduleNote string               `json:"sunday_schedule_note"`
}

// ValidateMealForDay ensures that on Sunday only brunch and dinner are served,
// and on Monday-Saturday breakfast, lunch, and dinner are served.
func ValidateMealForDay(dayOfWeek string, meal MealType) error {
	normalizedDay := strings.ToLower(strings.TrimSpace(dayOfWeek))
	normalizedMeal := MealType(strings.ToLower(strings.TrimSpace(string(meal))))

	if normalizedDay == "sunday" {
		if normalizedMeal == MealBreakfast || normalizedMeal == MealLunch {
			return fmt.Errorf("on Sunday, brunch replaces breakfast and lunch; '%s' is not scheduled", normalizedMeal)
		}
		if normalizedMeal != MealBrunch && normalizedMeal != MealDinner {
			return fmt.Errorf("invalid Sunday meal type '%s'; only 'brunch' and 'dinner' are offered", normalizedMeal)
		}
		return nil
	}

	// Monday - Saturday (6 days a week)
	validDays := map[string]bool{
		"monday": true, "tuesday": true, "wednesday": true,
		"thursday": true, "friday": true, "saturday": true,
	}
	if !validDays[normalizedDay] {
		return fmt.Errorf("invalid day of week '%s'", dayOfWeek)
	}

	if normalizedMeal == MealBrunch {
		return fmt.Errorf("brunch is exclusively served on Sunday; '%s' provides 3 meals: breakfast, lunch, dinner", normalizedDay)
	}
	if normalizedMeal != MealBreakfast && normalizedMeal != MealLunch && normalizedMeal != MealDinner {
		return fmt.Errorf("invalid meal type '%s' for '%s'; expected 'breakfast', 'lunch', or 'dinner'", normalizedMeal, normalizedDay)
	}

	return nil
}

// IsFeedbackCompulsory returns true if the rating requires a non-empty feedback message.
// Compulsory for very_poor, poor, and average; optional for good, very_good, and abstained.
func IsFeedbackCompulsory(rating RatingValue) bool {
	switch rating {
	case RatingVeryPoor, RatingPoor, RatingAverage:
		return true
	default:
		return false
	}
}

// ValidateRatingSubmission validates the rating and checks message compulsory rule.
func ValidateRatingSubmission(rating RatingValue, message string) error {
	switch rating {
	case RatingVeryPoor, RatingPoor, RatingAverage, RatingGood, RatingVeryGood, RatingAbstained:
		// Valid rating enum
	default:
		return fmt.Errorf("invalid rating value '%s'; must be very_poor, poor, average, good, very_good, or abstained", rating)
	}

	trimmedMsg := strings.TrimSpace(message)
	if IsFeedbackCompulsory(rating) && trimmedMsg == "" {
		return fmt.Errorf("feedback message is compulsory for %s rating", rating)
	}

	return nil
}
