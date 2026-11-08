package service

import (
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"

	"campus/backend/internal/model"
	"github.com/jackc/pgx/v5/pgxpool"
)

type MessService struct {
	db          *pgxpool.Pool
	permService *PermissionService
	mu          sync.RWMutex

	meals   map[string]*model.MessMeal   // mealID -> MessMeal
	ratings map[string]*model.MessRating // ratingID -> MessRating
}

func NewMessService(db *pgxpool.Pool, permService *PermissionService) *MessService {
	svc := &MessService{
		db:          db,
		permService: permService,
		meals:       make(map[string]*model.MessMeal),
		ratings:     make(map[string]*model.MessRating),
	}
	svc.SeedDefaultMenuAndReviews()
	return svc
}

// SeedDefaultMenuAndReviews seeds the weekly mess timetable conforming to:
// - Monday to Saturday: 3 meals a day (Breakfast, Lunch, Dinner)
// - Sunday: Brunch (replaces Breakfast & Lunch) and Dinner
func (s *MessService) SeedDefaultMenuAndReviews() {
	s.mu.Lock()
	defer s.mu.Unlock()

	days := []string{"monday", "tuesday", "wednesday", "thursday", "friday", "saturday"}
	for _, day := range days {
		dayTitle := strings.ToUpper(day[:1]) + day[1:]

		// Breakfast
		bId := fmt.Sprintf("meal-%s-breakfast", day)
		s.meals[bId] = &model.MessMeal{
			ID:          bId,
			DayOfWeek:   day,
			MealType:    model.MealBreakfast,
			StartTime:   "07:30",
			EndTime:     "09:30",
			Title:       fmt.Sprintf("%s Breakfast", dayTitle),
			MenuSummary: "Idli, Vada, Sambar, Coconut Chutney, Bread Butter, Tea / Coffee",
			Items:       []string{"Idli (3 pcs)", "Medu Vada (1 pc)", "Sambar", "Chutney", "Bread & Jam", "Tea / Coffee"},
		}

		// Lunch
		lId := fmt.Sprintf("meal-%s-lunch", day)
		s.meals[lId] = &model.MessMeal{
			ID:          lId,
			DayOfWeek:   day,
			MealType:    model.MealLunch,
			StartTime:   "12:30",
			EndTime:     "14:30",
			Title:       fmt.Sprintf("%s Lunch", dayTitle),
			MenuSummary: "Steamed Basmati Rice, Chapati, Dal Tadka, Paneer Butter Masala, Curd, Green Salad",
			Items:       []string{"Basmati Rice", "Tawa Roti", "Dal Tadka", "Paneer Sabzi", "Curd", "Kachumber Salad"},
		}

		// Dinner
		dId := fmt.Sprintf("meal-%s-dinner", day)
		s.meals[dId] = &model.MessMeal{
			ID:          dId,
			DayOfWeek:   day,
			MealType:    model.MealDinner,
			StartTime:   "19:30",
			EndTime:     "21:30",
			Title:       fmt.Sprintf("%s Dinner", dayTitle),
			MenuSummary: "Phulka, Jeera Rice, Rajma Curry, Mix Veg Poriyal, Gulab Jamun, Buttermilk",
			Items:       []string{"Phulka", "Jeera Rice", "Punjabi Rajma", "Dry Mix Veg", "Gulab Jamun", "Spiced Buttermilk"},
		}
	}

	// Sunday: Brunch instead of Breakfast and Lunch!
	brunchId := "meal-sunday-brunch"
	s.meals[brunchId] = &model.MessMeal{
		ID:          brunchId,
		DayOfWeek:   "sunday",
		MealType:    model.MealBrunch,
		StartTime:   "10:00",
		EndTime:     "13:00",
		Title:       "Sunday Grand Brunch (Replaces Breakfast & Lunch)",
		MenuSummary: "Chole Bhature, Masala Dosa Counter, Poha, Fresh Fruit Platter, Cold Coffee, Badam Milk",
		Items:       []string{"Chole Bhature (2 pcs)", "Live Masala Dosa", "Indori Poha", "Cut Fruit Salad", "Iced Cold Coffee", "Kesar Badam Milk"},
	}

	// Sunday Dinner
	sunDinnerId := "meal-sunday-dinner"
	s.meals[sunDinnerId] = &model.MessMeal{
		ID:          sunDinnerId,
		DayOfWeek:   "sunday",
		MealType:    model.MealDinner,
		StartTime:   "19:30",
		EndTime:     "21:30",
		Title:       "Sunday Special Dinner",
		MenuSummary: "Veg Biryani / Chicken Biryani, Mirchi Ka Salan, Raita, Rasmalai, Ice Cream",
		Items:       []string{"Hyderabadi Biryani", "Mirchi Ka Salan", "Boondi Raita", "Rasmalai", "Vanilla Cup"},
	}

	now := time.Now().UTC()

	// Seed Sample Ratings & Compulsory/Optional Messages
	sampleRatings := []*model.MessRating{
		{
			ID:           "rate-001",
			MealID:       brunchId,
			DayOfWeek:    "sunday",
			MealType:     model.MealBrunch,
			UserID:       "u-student-harish",
			UserName:     "Harish Kumar",
			CampusHandle: "harish_2025_l_btech_1",
			Rating:       model.RatingVeryGood,
			Message:      "The Sunday live dosa counter was exceptional this week, crispy and fresh.",
			CreatedAt:    now.Add(-14 * time.Hour),
		},
		{
			ID:           "rate-002",
			MealID:       brunchId,
			DayOfWeek:    "sunday",
			MealType:     model.MealBrunch,
			UserID:       "u-student-rohit",
			UserName:     "Rohit Verma",
			CampusHandle: "rohit_2025_btech_2",
			Rating:       model.RatingGood,
			Message:      "Brunch timings from 10:00 to 13:00 work very well on weekends.",
			CreatedAt:    now.Add(-12 * time.Hour),
		},
		{
			ID:           "rate-003",
			MealID:       "meal-saturday-dinner",
			DayOfWeek:    "saturday",
			MealType:     model.MealDinner,
			UserID:       "u-student-amit",
			UserName:     "Amit Shah",
			CampusHandle: "amit_2025_btech_3",
			Rating:       model.RatingPoor,
			Message:      "Dal was overly salty and chapatis were cold by 20:30.", // Compulsory feedback
			CreatedAt:    now.Add(-28 * time.Hour),
		},
		{
			ID:           "rate-004",
			MealID:       "meal-friday-lunch",
			DayOfWeek:    "friday",
			MealType:     model.MealLunch,
			UserID:       "u-student-harish",
			UserName:     "Harish Kumar",
			CampusHandle: "harish_2025_l_btech_1",
			Rating:       model.RatingAverage,
			Message:      "Paneer cubes were slightly rubbery, but the rice quality was good.", // Compulsory feedback
			CreatedAt:    now.Add(-46 * time.Hour),
		},
		{
			ID:           "rate-005",
			MealID:       "meal-friday-breakfast",
			DayOfWeek:    "friday",
			MealType:     model.MealBreakfast,
			UserID:       "u-student-priya",
			UserName:     "Priya Sharma",
			CampusHandle: "priya_2025_btech_4",
			Rating:       model.RatingVeryPoor,
			Message:      "Chutney was fermented and smelled sour; reported to mess vendor immediately.", // Compulsory feedback
			CreatedAt:    now.Add(-52 * time.Hour),
		},
		{
			ID:           "rate-006",
			MealID:       "meal-thursday-dinner",
			DayOfWeek:    "thursday",
			MealType:     model.MealDinner,
			UserID:       "u-student-rohit",
			UserName:     "Rohit Verma",
			CampusHandle: "rohit_2025_btech_2",
			Rating:       model.RatingAbstained,
			Message:      "", // Optional for abstained
			CreatedAt:    now.Add(-70 * time.Hour),
		},
	}

	for _, r := range sampleRatings {
		s.ratings[r.ID] = r
	}
}

// GetWeeklyTimetable returns all scheduled meals for the week ordered by day and timing.
func (s *MessService) GetWeeklyTimetable() []model.MessMeal {
	s.mu.RLock()
	defer s.mu.RUnlock()

	dayOrder := map[string]int{
		"monday": 1, "tuesday": 2, "wednesday": 3,
		"thursday": 4, "friday": 5, "saturday": 6, "sunday": 7,
	}

	mealOrder := map[model.MealType]int{
		model.MealBreakfast: 1,
		model.MealBrunch:    2,
		model.MealLunch:     3,
		model.MealDinner:    4,
	}

	result := make([]model.MessMeal, 0, len(s.meals))
	for _, m := range s.meals {
		result = append(result, *m)
	}

	sort.Slice(result, func(i, j int) bool {
		d1, d2 := dayOrder[result[i].DayOfWeek], dayOrder[result[j].DayOfWeek]
		if d1 != d2 {
			return d1 < d2
		}
		return mealOrder[result[i].MealType] < mealOrder[result[j].MealType]
	})

	return result
}

// GetMealByID returns a specific meal slot.
func (s *MessService) GetMealByID(id string) (*model.MessMeal, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	meal, exists := s.meals[id]
	if !exists {
		return nil, fmt.Errorf("mess meal '%s' not found", id)
	}
	mCopy := *meal
	return &mCopy, nil
}

// SubmitRatingRequest defines payload for submitting student meal feedback.
type SubmitRatingRequest struct {
	MealID       string            `json:"meal_id"`
	UserID       string            `json:"user_id"`
	UserName     string            `json:"user_name"`
	CampusHandle string            `json:"campus_handle"`
	Rating       model.RatingValue `json:"rating"`
	Message      string            `json:"message"`
}

// SubmitRating validates rating boundaries, enforces Sunday brunch schedule and compulsory message constraints.
func (s *MessService) SubmitRating(req SubmitRatingRequest) (*model.MessRating, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	meal, exists := s.meals[req.MealID]
	if !exists {
		return nil, fmt.Errorf("meal '%s' does not exist in mess timetable", req.MealID)
	}

	// Validate meal type for day (e.g. Sunday brunch constraint)
	if err := model.ValidateMealForDay(meal.DayOfWeek, meal.MealType); err != nil {
		return nil, err
	}

	// Validate rating and compulsory message for very_poor, poor, average
	if err := model.ValidateRatingSubmission(req.Rating, req.Message); err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	ratingID := fmt.Sprintf("rate-%d", now.UnixNano())
	record := &model.MessRating{
		ID:           ratingID,
		MealID:       meal.ID,
		DayOfWeek:    meal.DayOfWeek,
		MealType:     meal.MealType,
		UserID:       strings.TrimSpace(req.UserID),
		UserName:     strings.TrimSpace(req.UserName),
		CampusHandle: strings.TrimSpace(req.CampusHandle),
		Rating:       req.Rating,
		Message:      strings.TrimSpace(req.Message),
		CreatedAt:    now,
	}

	s.ratings[ratingID] = record
	return record, nil
}

// GetRatingsReport computes metrics and returns feedback messages.
func (s *MessService) GetRatingsReport(mealID string, ratingFilter string) model.MessReportSummary {
	s.mu.RLock()
	defer s.mu.RUnlock()

	counts := map[model.RatingValue]int{
		model.RatingVeryPoor:  0,
		model.RatingPoor:      0,
		model.RatingAverage:   0,
		model.RatingGood:      0,
		model.RatingVeryGood:  0,
		model.RatingAbstained: 0,
	}

	totalScore := 0.0
	scoredCount := 0
	totalRatings := 0
	messages := make([]model.MessRating, 0)

	for _, r := range s.ratings {
		if mealID != "" && r.MealID != mealID {
			continue
		}

		counts[r.Rating]++
		totalRatings++

		// Scoring: very_poor=1, poor=2, average=3, good=4, very_good=5
		switch r.Rating {
		case model.RatingVeryPoor:
			totalScore += 1.0
			scoredCount++
		case model.RatingPoor:
			totalScore += 2.0
			scoredCount++
		case model.RatingAverage:
			totalScore += 3.0
			scoredCount++
		case model.RatingGood:
			totalScore += 4.0
			scoredCount++
		case model.RatingVeryGood:
			totalScore += 5.0
			scoredCount++
		case model.RatingAbstained:
			// Abstained does not skew average score
		}

		// Apply message rating filter if specified
		if ratingFilter == "" || string(r.Rating) == ratingFilter ||
			(ratingFilter == "compulsory" && model.IsFeedbackCompulsory(r.Rating)) {
			messages = append(messages, *r)
		}
	}

	// Sort messages newest first
	sort.Slice(messages, func(i, j int) bool {
		return messages[i].CreatedAt.After(messages[j].CreatedAt)
	})

	avgScore := 0.0
	if scoredCount > 0 {
		avgScore = totalScore / float64(scoredCount)
	}

	return model.MessReportSummary{
		TotalRatings:       totalRatings,
		AverageScore:       avgScore,
		RatingCounts:       counts,
		RecentMessages:     messages,
		SundayScheduleNote: "On Sunday, Brunch (10:00 - 13:00) replaces Breakfast and Lunch. Dinner is served at 19:30 - 21:30.",
	}
}
