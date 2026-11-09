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

type HostelService struct {
	db          *pgxpool.Pool
	permService *PermissionService
	mu          sync.RWMutex

	rooms   map[int]*model.HostelRoom // roomNumber (100 - 999) -> room
	serials map[string]int            // serialNumber (<= 14 chars) -> roomNumber
}

func NewHostelService(db *pgxpool.Pool, permService *PermissionService) *HostelService {
	svc := &HostelService{
		db:          db,
		permService: permService,
		rooms:       make(map[int]*model.HostelRoom),
		serials:     make(map[string]int),
	}
	svc.SeedDefaultRooms()
	return svc
}

// CreateRoom registers a new room number (100 to 999)
func (s *HostelService) CreateRoom(roomNumber int, blockName string) (*model.HostelRoom, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if err := model.ValidateRoomNumber(roomNumber); err != nil {
		return nil, err
	}

	if _, exists := s.rooms[roomNumber]; exists {
		return nil, fmt.Errorf("hostel room %d already exists", roomNumber)
	}

	if strings.TrimSpace(blockName) == "" {
		blockName = "Aryabhatta Block"
	}

	now := time.Now().UTC()
	room := &model.HostelRoom{
		ID:         fmt.Sprintf("room-%d", roomNumber),
		RoomNumber: roomNumber,
		BlockName:  strings.TrimSpace(blockName),
		Floor:      roomNumber / 100,
		Assets:     make([]model.HostelAsset, 0),
		Occupants:  make([]model.HostelOccupant, 0),
		CreatedAt:  now,
		UpdatedAt:  now,
	}

	s.rooms[roomNumber] = room
	return room, nil
}

// GetRooms returns all registered hostel rooms sorted ascending by room number
func (s *HostelService) GetRooms() ([]model.HostelRoom, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	result := make([]model.HostelRoom, 0, len(s.rooms))
	for _, r := range s.rooms {
		result = append(result, *r)
	}

	sort.Slice(result, func(i, j int) bool {
		return result[i].RoomNumber < result[j].RoomNumber
	})

	return result, nil
}

// GetRoomByNumber returns a specific room by its 100-999 room number
func (s *HostelService) GetRoomByNumber(roomNumber int) (*model.HostelRoom, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if err := model.ValidateRoomNumber(roomNumber); err != nil {
		return nil, err
	}

	room, exists := s.rooms[roomNumber]
	if !exists {
		return nil, fmt.Errorf("hostel room %d not found", roomNumber)
	}

	// Return a copy
	roomCopy := *room
	roomCopy.Assets = append([]model.HostelAsset(nil), room.Assets...)
	roomCopy.Occupants = append([]model.HostelOccupant(nil), room.Occupants...)
	return &roomCopy, nil
}

// AddAsset registers an asset fixture (bed, table, tubelight, fan, locker) with a 14-character alphanumeric serial number
func (s *HostelService) AddAsset(roomNumber int, assetType string, serialNumber string, condition string) (*model.HostelAsset, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if err := model.ValidateRoomNumber(roomNumber); err != nil {
		return nil, err
	}

	room, exists := s.rooms[roomNumber]
	if !exists {
		return nil, fmt.Errorf("hostel room %d not found", roomNumber)
	}

	normalizedType := strings.ToLower(strings.TrimSpace(assetType))
	if ok, reason := room.CanAddAsset(normalizedType); !ok {
		return nil, fmt.Errorf("cannot add asset: %s", reason)
	}

	trimmedSerial := strings.TrimSpace(serialNumber)
	if err := model.ValidateSerialNumber(trimmedSerial); err != nil {
		return nil, err
	}

	// Check serial uniqueness
	if existingRoom, exists := s.serials[trimmedSerial]; exists {
		return nil, fmt.Errorf("serial number '%s' is already assigned to room %d", trimmedSerial, existingRoom)
	}

	if condition == "" {
		condition = "operational"
	}

	asset := model.HostelAsset{
		ID:           fmt.Sprintf("asset-%d-%s-%d", roomNumber, normalizedType, time.Now().UnixNano()),
		RoomNumber:   roomNumber,
		AssetType:    normalizedType,
		SerialNumber: trimmedSerial,
		Condition:    condition,
		InstalledAt:  time.Now().UTC(),
	}

	room.Assets = append(room.Assets, asset)
	room.UpdatedAt = time.Now().UTC()
	s.serials[trimmedSerial] = roomNumber

	return &asset, nil
}

// RemoveAsset deletes an asset by ID from a room
func (s *HostelService) RemoveAsset(roomNumber int, assetID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	room, exists := s.rooms[roomNumber]
	if !exists {
		return fmt.Errorf("hostel room %d not found", roomNumber)
	}

	foundIdx := -1
	var removedSerial string
	for i, a := range room.Assets {
		if a.ID == assetID || a.SerialNumber == assetID {
			foundIdx = i
			removedSerial = a.SerialNumber
			break
		}
	}

	if foundIdx == -1 {
		return fmt.Errorf("asset '%s' not found in room %d", assetID, roomNumber)
	}

	room.Assets = append(room.Assets[:foundIdx], room.Assets[foundIdx+1:]...)
	room.UpdatedAt = time.Now().UTC()
	delete(s.serials, removedSerial)

	return nil
}

// AssignOccupant adds a student resident to a room (up to 3 occupants max)
func (s *HostelService) AssignOccupant(roomNumber int, userID string, handle string, name string) (*model.HostelOccupant, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if err := model.ValidateRoomNumber(roomNumber); err != nil {
		return nil, err
	}

	room, exists := s.rooms[roomNumber]
	if !exists {
		return nil, fmt.Errorf("hostel room %d not found", roomNumber)
	}

	if ok, reason := room.CanAddOccupant(); !ok {
		return nil, fmt.Errorf("cannot assign occupant: %s", reason)
	}

	// Verify student isn't already assigned to any room
	trimmedUserID := strings.TrimSpace(userID)
	trimmedHandle := strings.TrimSpace(handle)
	for _, r := range s.rooms {
		for _, occ := range r.Occupants {
			if (trimmedUserID != "" && occ.UserID == trimmedUserID) || (trimmedHandle != "" && occ.CampusHandle == trimmedHandle) {
				return nil, fmt.Errorf("resident %s is already allocated to room %d", occ.Name, r.RoomNumber)
			}
		}
	}

	occupant := model.HostelOccupant{
		UserID:       trimmedUserID,
		CampusHandle: trimmedHandle,
		Name:         strings.TrimSpace(name),
		AllottedAt:   time.Now().UTC(),
	}

	room.Occupants = append(room.Occupants, occupant)
	room.UpdatedAt = time.Now().UTC()

	return &occupant, nil
}

// RemoveOccupant discharges an occupant from a room
func (s *HostelService) RemoveOccupant(roomNumber int, identifier string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	room, exists := s.rooms[roomNumber]
	if !exists {
		return fmt.Errorf("hostel room %d not found", roomNumber)
	}

	foundIdx := -1
	for i, occ := range room.Occupants {
		if occ.UserID == identifier || occ.CampusHandle == identifier {
			foundIdx = i
			break
		}
	}

	if foundIdx == -1 {
		return fmt.Errorf("occupant '%s' not found in room %d", identifier, roomNumber)
	}

	room.Occupants = append(room.Occupants[:foundIdx], room.Occupants[foundIdx+1:]...)
	room.UpdatedAt = time.Now().UTC()

	return nil
}

// UpdateRoom updates room number and block name
func (s *HostelService) UpdateRoom(originalRoomNumber int, newRoomNumber int, blockName string) (*model.HostelRoom, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if err := model.ValidateRoomNumber(originalRoomNumber); err != nil {
		return nil, err
	}
	if err := model.ValidateRoomNumber(newRoomNumber); err != nil {
		return nil, err
	}

	room, exists := s.rooms[originalRoomNumber]
	if !exists {
		return nil, fmt.Errorf("hostel room %d not found", originalRoomNumber)
	}

	if newRoomNumber != originalRoomNumber {
		if _, alreadyExists := s.rooms[newRoomNumber]; alreadyExists {
			return nil, fmt.Errorf("hostel room %d already exists", newRoomNumber)
		}
		delete(s.rooms, originalRoomNumber)
		room.RoomNumber = newRoomNumber
		room.ID = fmt.Sprintf("room-%d", newRoomNumber)
		room.Floor = newRoomNumber / 100
		for i := range room.Assets {
			room.Assets[i].RoomNumber = newRoomNumber
			s.serials[room.Assets[i].SerialNumber] = newRoomNumber
		}
		s.rooms[newRoomNumber] = room
	}

	if strings.TrimSpace(blockName) != "" {
		room.BlockName = strings.TrimSpace(blockName)
	}
	room.UpdatedAt = time.Now().UTC()

	return room, nil
}

// UpdateAsset updates an asset fixture's serial number and condition
func (s *HostelService) UpdateAsset(roomNumber int, assetID string, newSerialNumber string, condition string) (*model.HostelAsset, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	room, exists := s.rooms[roomNumber]
	if !exists {
		return nil, fmt.Errorf("hostel room %d not found", roomNumber)
	}

	foundIdx := -1
	for i, a := range room.Assets {
		if a.ID == assetID || a.SerialNumber == assetID {
			foundIdx = i
			break
		}
	}
	if foundIdx == -1 {
		return nil, fmt.Errorf("asset '%s' not found in room %d", assetID, roomNumber)
	}

	trimmedSerial := strings.TrimSpace(newSerialNumber)
	if trimmedSerial != "" {
		if err := model.ValidateSerialNumber(trimmedSerial); err != nil {
			return nil, err
		}
		oldSerial := room.Assets[foundIdx].SerialNumber
		if trimmedSerial != oldSerial {
			if existingRoom, exists := s.serials[trimmedSerial]; exists && existingRoom != roomNumber {
				return nil, fmt.Errorf("serial number '%s' is already assigned to room %d", trimmedSerial, existingRoom)
			}
			delete(s.serials, oldSerial)
			s.serials[trimmedSerial] = roomNumber
			room.Assets[foundIdx].SerialNumber = trimmedSerial
		}
	}

	if strings.TrimSpace(condition) != "" {
		room.Assets[foundIdx].Condition = strings.TrimSpace(condition)
	}
	room.UpdatedAt = time.Now().UTC()

	assetCopy := room.Assets[foundIdx]
	return &assetCopy, nil
}

// SeedDefaultRooms populates default compliant rooms within the 100-999 range
func (s *HostelService) SeedDefaultRooms() {
	// Room 101: Ground/First floor, fully furnished, 2 occupants
	r101, _ := s.CreateRoom(101, "Aryabhatta Block")
	if r101 != nil {
		// 3 Beds (14-char serials)
		_, _ = s.AddAsset(101, model.HostelAssetBed, "BED-101-01", "operational")
		_, _ = s.AddAsset(101, model.HostelAssetBed, "BED-101-02", "operational")
		_, _ = s.AddAsset(101, model.HostelAssetBed, "BED-101-03", "operational")
		// 3 Tables
		_, _ = s.AddAsset(101, model.HostelAssetTable, "TAB-101-01", "operational")
		_, _ = s.AddAsset(101, model.HostelAssetTable, "TAB-101-02", "operational")
		_, _ = s.AddAsset(101, model.HostelAssetTable, "TAB-101-03", "operational")
		// 3 Chairs
		_, _ = s.AddAsset(101, model.HostelAssetChair, "CHR-101-01", "operational")
		_, _ = s.AddAsset(101, model.HostelAssetChair, "CHR-101-02", "operational")
		_, _ = s.AddAsset(101, model.HostelAssetChair, "CHR-101-03", "operational")
		// 2 Tubelights
		_, _ = s.AddAsset(101, model.HostelAssetTubelight, "TL-101-01", "operational")
		_, _ = s.AddAsset(101, model.HostelAssetTubelight, "TL-101-02", "operational")
		// 2 Fans
		_, _ = s.AddAsset(101, model.HostelAssetFan, "FAN-101-01", "operational")
		_, _ = s.AddAsset(101, model.HostelAssetFan, "FAN-101-02", "operational")
		// 3 Lockers
		_, _ = s.AddAsset(101, model.HostelAssetLocker, "LCK-101-01", "operational")
		_, _ = s.AddAsset(101, model.HostelAssetLocker, "LCK-101-02", "operational")
		_, _ = s.AddAsset(101, model.HostelAssetLocker, "LCK-101-03", "operational")
		// 2 Occupants
		_, _ = s.AssignOccupant(101, "u-student-harish", "harish_2025_l_btech_1", "Harish Kumar")
		_, _ = s.AssignOccupant(101, "u-student-rohit", "rohit_2025_btech_2", "Rohit Verma")
	}

	// Room 102: First floor, 2 beds, 2 tables, 2 tubelights, 1 fan, 2 lockers, 1 occupant
	r102, _ := s.CreateRoom(102, "Aryabhatta Block")
	if r102 != nil {
		_, _ = s.AddAsset(102, model.HostelAssetBed, "BED-102-01", "operational")
		_, _ = s.AddAsset(102, model.HostelAssetBed, "BED-102-02", "operational")
		_, _ = s.AddAsset(102, model.HostelAssetTable, "TAB-102-01", "operational")
		_, _ = s.AddAsset(102, model.HostelAssetTable, "TAB-102-02", "operational")
		_, _ = s.AddAsset(102, model.HostelAssetChair, "CHR-102-01", "operational")
		_, _ = s.AddAsset(102, model.HostelAssetChair, "CHR-102-02", "operational")
		_, _ = s.AddAsset(102, model.HostelAssetTubelight, "TL-102-01", "operational")
		_, _ = s.AddAsset(102, model.HostelAssetTubelight, "TL-102-02", "operational")
		_, _ = s.AddAsset(102, model.HostelAssetFan, "FAN-102-01", "operational")
		_, _ = s.AddAsset(102, model.HostelAssetLocker, "LCK-102-01", "operational")
		_, _ = s.AddAsset(102, model.HostelAssetLocker, "LCK-102-02", "operational")
		_, _ = s.AssignOccupant(102, "u-student-amit", "amit_2025_btech_3", "Amit Shah")
	}

	// Room 204: Second floor, vacant room ready for allotment
	r204, _ := s.CreateRoom(204, "Aryabhatta Block")
	if r204 != nil {
		_, _ = s.AddAsset(204, model.HostelAssetBed, "BED-204-01", "operational")
		_, _ = s.AddAsset(204, model.HostelAssetBed, "BED-204-02", "operational")
		_, _ = s.AddAsset(204, model.HostelAssetBed, "BED-204-03", "operational")
		_, _ = s.AddAsset(204, model.HostelAssetTable, "TAB-204-01", "operational")
		_, _ = s.AddAsset(204, model.HostelAssetTable, "TAB-204-02", "operational")
		_, _ = s.AddAsset(204, model.HostelAssetTable, "TAB-204-03", "operational")
		_, _ = s.AddAsset(204, model.HostelAssetChair, "CHR-204-01", "operational")
		_, _ = s.AddAsset(204, model.HostelAssetChair, "CHR-204-02", "operational")
		_, _ = s.AddAsset(204, model.HostelAssetChair, "CHR-204-03", "operational")
		_, _ = s.AddAsset(204, model.HostelAssetTubelight, "TL-204-01", "operational")
		_, _ = s.AddAsset(204, model.HostelAssetTubelight, "TL-204-02", "operational")
		_, _ = s.AddAsset(204, model.HostelAssetFan, "FAN-204-01", "operational")
		_, _ = s.AddAsset(204, model.HostelAssetFan, "FAN-204-02", "operational")
		_, _ = s.AddAsset(204, model.HostelAssetLocker, "LCK-204-01", "operational")
		_, _ = s.AddAsset(204, model.HostelAssetLocker, "LCK-204-02", "operational")
		_, _ = s.AddAsset(204, model.HostelAssetLocker, "LCK-204-03", "operational")
	}

	// Room 305: Third floor
	r305, _ := s.CreateRoom(305, "Aryabhatta Block")
	if r305 != nil {
		_, _ = s.AddAsset(305, model.HostelAssetBed, "BED-305-01", "operational")
		_, _ = s.AddAsset(305, model.HostelAssetTable, "TAB-305-01", "operational")
		_, _ = s.AddAsset(305, model.HostelAssetChair, "CHR-305-01", "operational")
		_, _ = s.AddAsset(305, model.HostelAssetTubelight, "TL-305-01", "operational")
		_, _ = s.AddAsset(305, model.HostelAssetFan, "FAN-305-01", "operational")
		_, _ = s.AddAsset(305, model.HostelAssetLocker, "LCK-305-01", "operational")
	}
}
