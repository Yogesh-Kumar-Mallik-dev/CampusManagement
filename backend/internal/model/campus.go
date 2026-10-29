package model

import "time"

// BaseSyncModel contains audit columns required for delta sync
type BaseSyncModel struct {
	ID        string    `json:"id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	IsDeleted bool      `json:"is_deleted"`
}

// Student represents a campus student record
type Student struct {
	BaseSyncModel
	RollNumber string `json:"roll_number"`
	FullName   string `json:"full_name"`
	Email      string `json:"email"`
	Department string `json:"department"`
	Semester   int    `json:"semester"`
}

// TimetableEntry represents a scheduled lecture/lab
type TimetableEntry struct {
	BaseSyncModel
	Department string `json:"department"`
	Semester   int    `json:"semester"`
	DayOfWeek  string `json:"day_of_week"`
	StartTime  string `json:"start_time"`
	EndTime    string `json:"end_time"`
	Subject    string `json:"subject"`
	RoomNumber string `json:"room_number"`
	Teacher    string `json:"teacher"`
}

// Notice represents a campus broadcast announcement
type Notice struct {
	BaseSyncModel
	Title       string `json:"title"`
	Content     string `json:"content"`
	Category    string `json:"category"`
	Publisher   string `json:"publisher"`
	PublishedAt time.Time `json:"published_at"`
}

// DeltaSyncResponse returns updated and deleted records since requested timestamp
type DeltaSyncResponse struct {
	ServerTime time.Time        `json:"server_time"`
	Notices    []Notice         `json:"notices"`
	Timetables []TimetableEntry `json:"timetables"`
}
