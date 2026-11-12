package model

import (
	"fmt"
	"regexp"
	"strings"
	"time"
)

// Hostel system operational boundaries & inventory capacity constraints
const (
	MinHostelRoomNumber = 100
	MaxHostelRoomNumber = 999

	MaxBedsPerRoom       = 3
	MaxTablesPerRoom     = 3
	MaxChairsPerRoom     = 3
	MaxTubelightsPerRoom = 2
	MaxFansPerRoom       = 2
	MaxLockersPerRoom    = 3
	MaxOccupantsPerRoom  = 3

	MaxSerialNumberLength = 14
)

// Standard Hostel Asset Types
const (
	HostelAssetBed       = "bed"
	HostelAssetTable     = "table"
	HostelAssetChair     = "chair"
	HostelAssetTubelight = "tubelight"
	HostelAssetFan       = "fan"
	HostelAssetLocker    = "locker"
)

// Regex for alphanumeric serial number validation (allowing uppercase, lowercase, digits, and hyphen/underscore)
var serialRegex = regexp.MustCompile(`^[A-Za-z0-9\-_]{1,14}$`)

// ValidateRoomNumber ensures room numbers are strictly within 100 to 999
func ValidateRoomNumber(num int) error {
	if num < MinHostelRoomNumber || num > MaxHostelRoomNumber {
		return fmt.Errorf("room number %d is outside permitted range [100 - 999]", num)
	}
	return nil
}

// DeriveFloor computes the hostel floor (0 to 4) from the room number.
// Floor 0: rooms 101-199
// Floor 1: rooms 201-299
// Floor 2: rooms 301-399
// Floor 3: rooms 401-499
// Floor 4: rooms 501-599
func DeriveFloor(roomNumber int) int {
	f := (roomNumber / 100) - 1
	if f < 0 {
		return 0
	}
	if f > 4 {
		return 4
	}
	return f
}

// ValidateSerialNumber ensures alphanumeric format and maximum 14 characters
func ValidateSerialNumber(sn string) error {
	trimmed := strings.TrimSpace(sn)
	if trimmed == "" {
		return fmt.Errorf("serial number cannot be empty")
	}
	if len(trimmed) > MaxSerialNumberLength {
		return fmt.Errorf("serial number '%s' exceeds maximum allowed length of %d alphanumeric characters", trimmed, MaxSerialNumberLength)
	}
	if !serialRegex.MatchString(trimmed) {
		return fmt.Errorf("serial number '%s' must be alphanumeric (up to %d characters)", trimmed, MaxSerialNumberLength)
	}
	return nil
}

// MaxCapacityForAsset returns the strict upper limit for each fixture asset type
func MaxCapacityForAsset(assetType string) int {
	switch strings.ToLower(assetType) {
	case HostelAssetBed:
		return MaxBedsPerRoom
	case HostelAssetTable:
		return MaxTablesPerRoom
	case HostelAssetChair:
		return MaxChairsPerRoom
	case HostelAssetTubelight:
		return MaxTubelightsPerRoom
	case HostelAssetFan:
		return MaxFansPerRoom
	case HostelAssetLocker:
		return MaxLockersPerRoom
	default:
		return 0
	}
}

// HostelAsset represents an inventoried room fixture with a 14-char alphanumeric serial number
type HostelAsset struct {
	ID           string    `json:"id"`
	RoomNumber   int       `json:"room_number"`
	AssetType    string    `json:"asset_type"` // 'bed', 'table', 'chair', 'tubelight', 'fan', 'locker'
	SerialNumber string    `json:"serial_number"` // at most 14 alphanumeric chars
	Condition    string    `json:"condition"`     // 'operational', 'maintenance_needed', 'damaged'
	InstalledAt  time.Time `json:"installed_at"`
}

// HostelOccupant represents a student resident occupying a room
type HostelOccupant struct {
	UserID       string     `json:"user_id"`
	RoomID       string     `json:"room_id,omitempty"`
	RoomNumber   int        `json:"room_number,omitempty"`
	BedNumber    int        `json:"bed_number,omitempty"` // 1, 2, or 3
	CampusHandle string     `json:"campus_handle"`
	Name         string     `json:"name"`
	AllottedAt   time.Time  `json:"allotted_at"`
	VacatedAt    *time.Time `json:"vacated_at,omitempty"`
}

// HostelRoom represents a hostel room with bounded asset fixtures and student occupants
type HostelRoom struct {
	ID         string           `json:"id"`
	RoomNumber int              `json:"room_number"` // 100 to 999
	BlockName  string           `json:"block_name"`  // e.g. "Block 1", "Block 2", "Block 3", "Block 4"
	Floor      int              `json:"floor"`       // derived: (roomNumber / 100) - 1 (Floor 0: 101-199, Floor 1: 201-299, etc.)
	Assets     []HostelAsset    `json:"assets"`
	Occupants  []HostelOccupant `json:"occupants"`
	CreatedAt  time.Time        `json:"created_at"`
	UpdatedAt  time.Time        `json:"updated_at"`
}

// AssetCountByType returns the count of installed assets of a given type
func (r *HostelRoom) AssetCountByType(assetType string) int {
	normalized := strings.ToLower(assetType)
	count := 0
	for _, a := range r.Assets {
		if strings.ToLower(a.AssetType) == normalized {
			count++
		}
	}
	return count
}

// CanAddAsset checks if adding another asset of given type violates capacity or validation rules
func (r *HostelRoom) CanAddAsset(assetType string) (bool, string) {
	normalized := strings.ToLower(assetType)
	maxCap := MaxCapacityForAsset(normalized)
	if maxCap == 0 {
		return false, fmt.Sprintf("unknown asset type '%s'", assetType)
	}
	current := r.AssetCountByType(normalized)
	if current >= maxCap {
		return false, fmt.Sprintf("room %d already has %d/%d %ss (capacity reached)", r.RoomNumber, current, maxCap, normalized)
	}
	return true, ""
}

// CanAddOccupant checks if room can accommodate another student
func (r *HostelRoom) CanAddOccupant() (bool, string) {
	if len(r.Occupants) >= MaxOccupantsPerRoom {
		return false, fmt.Sprintf("room %d is at maximum occupant capacity (%d/%d)", r.RoomNumber, len(r.Occupants), MaxOccupantsPerRoom)
	}
	return true, ""
}
