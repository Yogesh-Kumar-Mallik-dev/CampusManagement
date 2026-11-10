package service

import (
	"strings"
	"testing"

	"campus/backend/internal/model"
)

func TestHostelRoomNumberValidation(t *testing.T) {
	svc := NewHostelService(nil, nil)

	// Valid room numbers: 100 to 999
	validRooms := []int{100, 101, 204, 550, 999}
	for _, num := range validRooms {
		if err := model.ValidateRoomNumber(num); err != nil {
			t.Errorf("expected room number %d to be valid, got: %v", num, err)
		}
	}

	// Invalid room numbers: below 100 or above 999
	invalidRooms := []int{0, 99, -100, 1000, 1500}
	for _, num := range invalidRooms {
		if err := model.ValidateRoomNumber(num); err == nil {
			t.Errorf("expected room number %d to be invalid, but validation passed", num)
		}
		_, err := svc.CreateRoom(num, "Block A")
		if err == nil {
			t.Errorf("expected CreateRoom(%d) to fail, but succeeded", num)
		}
	}
}

func TestHostelSerialNumberConstraints(t *testing.T) {
	// Valid serial numbers: <= 14 alphanumeric chars
	validSerials := []string{
		"12345678901234", // exactly 14 digits
		"BED-101-01",     // 10 chars
		"F101A",          // 5 chars
		"TL_ROOM_101_1",  // 13 chars
		"L999",
	}

	for _, s := range validSerials {
		if err := model.ValidateSerialNumber(s); err != nil {
			t.Errorf("expected serial '%s' to be valid, got: %v", s, err)
		}
	}

	// Invalid serial numbers: > 14 chars, empty, special chars
	invalidSerials := []string{
		"",                          // empty
		"   ",                       // whitespace
		"123456789012345",           // 15 digits (> 14)
		"VERY_LONG_SERIAL_NUMBER_X", // 25 chars
		"BED#101@01",                // special characters
	}

	for _, s := range invalidSerials {
		if err := model.ValidateSerialNumber(s); err == nil {
			t.Errorf("expected serial '%s' to fail validation, but passed", s)
		}
	}
}

func TestHostelCapacityLimits(t *testing.T) {
	svc := NewHostelService(nil, nil)
	roomNum := 401
	_, err := svc.CreateRoom(roomNum, "Test Block")
	if err != nil {
		t.Fatalf("failed to create room: %v", err)
	}

	// 1. Bed Capacity: Max 3
	for i := 1; i <= 3; i++ {
		_, err := svc.AddAsset(roomNum, model.HostelAssetBed, strings.ReplaceAll("BED-401-0X", "X", string(rune('0'+i))), "operational")
		if err != nil {
			t.Fatalf("failed to add bed %d: %v", i, err)
		}
	}
	// 4th Bed must fail
	_, err = svc.AddAsset(roomNum, model.HostelAssetBed, "BED-401-04", "operational")
	if err == nil {
		t.Errorf("expected 4th bed to exceed max capacity of 3, but succeeded")
	}

	// 2. Table Capacity: Max 3
	for i := 1; i <= 3; i++ {
		_, err := svc.AddAsset(roomNum, model.HostelAssetTable, strings.ReplaceAll("TAB-401-0X", "X", string(rune('0'+i))), "operational")
		if err != nil {
			t.Fatalf("failed to add table %d: %v", i, err)
		}
	}
	// 4th Table must fail
	_, err = svc.AddAsset(roomNum, model.HostelAssetTable, "TAB-401-04", "operational")
	if err == nil {
		t.Errorf("expected 4th table to exceed max capacity of 3, but succeeded")
	}

	// 3. Chair Capacity: Max 3
	for i := 1; i <= 3; i++ {
		_, err := svc.AddAsset(roomNum, model.HostelAssetChair, strings.ReplaceAll("CHR-401-0X", "X", string(rune('0'+i))), "operational")
		if err != nil {
			t.Fatalf("failed to add chair %d: %v", i, err)
		}
	}
	// 4th Chair must fail
	_, err = svc.AddAsset(roomNum, model.HostelAssetChair, "CHR-401-04", "operational")
	if err == nil {
		t.Errorf("expected 4th chair to exceed max capacity of 3, but succeeded")
	}

	// 3. Tubelight Capacity: Max 2
	for i := 1; i <= 2; i++ {
		_, err := svc.AddAsset(roomNum, model.HostelAssetTubelight, strings.ReplaceAll("TL-401-0X", "X", string(rune('0'+i))), "operational")
		if err != nil {
			t.Fatalf("failed to add tubelight %d: %v", i, err)
		}
	}
	// 3rd Tubelight must fail
	_, err = svc.AddAsset(roomNum, model.HostelAssetTubelight, "TL-401-03", "operational")
	if err == nil {
		t.Errorf("expected 3rd tubelight to exceed max capacity of 2, but succeeded")
	}

	// 4. Fan Capacity: Max 2
	for i := 1; i <= 2; i++ {
		_, err := svc.AddAsset(roomNum, model.HostelAssetFan, strings.ReplaceAll("FAN-401-0X", "X", string(rune('0'+i))), "operational")
		if err != nil {
			t.Fatalf("failed to add fan %d: %v", i, err)
		}
	}
	// 3rd Fan must fail
	_, err = svc.AddAsset(roomNum, model.HostelAssetFan, "FAN-401-03", "operational")
	if err == nil {
		t.Errorf("expected 3rd fan to exceed max capacity of 2, but succeeded")
	}

	// 5. Locker Capacity: Max 3
	for i := 1; i <= 3; i++ {
		_, err := svc.AddAsset(roomNum, model.HostelAssetLocker, strings.ReplaceAll("LCK-401-0X", "X", string(rune('0'+i))), "operational")
		if err != nil {
			t.Fatalf("failed to add locker %d: %v", i, err)
		}
	}
	// 4th Locker must fail
	_, err = svc.AddAsset(roomNum, model.HostelAssetLocker, "LCK-401-04", "operational")
	if err == nil {
		t.Errorf("expected 4th locker to exceed max capacity of 3, but succeeded")
	}

	// 6. Occupant Capacity: Max 3
	for i := 1; i <= 3; i++ {
		_, err := svc.AssignOccupant(roomNum, strings.ReplaceAll("u-40X", "X", string(rune('0'+i))), strings.ReplaceAll("stud_40X", "X", string(rune('0'+i))), "Test Student")
		if err != nil {
			t.Fatalf("failed to assign occupant %d: %v", i, err)
		}
	}
	// 4th Occupant must fail
	_, err = svc.AssignOccupant(roomNum, "u-404", "stud_404", "Extra Student")
	if err == nil {
		t.Errorf("expected 4th occupant to exceed max capacity of 3, but succeeded")
	}

	// Duplicate serial across system must fail
	_, err = svc.AddAsset(401, model.HostelAssetBed, "BED-101-01", "operational") // already seeded in 101
	if err == nil {
		t.Errorf("expected duplicate serial number BED-101-01 to fail, but succeeded")
	}

	// Verify removal of occupant and asset
	err = svc.RemoveOccupant(roomNum, "u-401")
	if err != nil {
		t.Fatalf("failed to remove occupant: %v", err)
	}

	// Now room has 2 occupants, so can add 1 more
	_, err = svc.AssignOccupant(roomNum, "u-404", "stud_404", "New Student")
	if err != nil {
		t.Fatalf("failed to assign occupant after removal: %v", err)
	}
}

func TestHostelEditRoomAndAsset(t *testing.T) {
	svc := NewHostelService(nil, nil)

	// Create room 450
	_, err := svc.CreateRoom(450, "Old Block")
	if err != nil {
		t.Fatalf("failed to create room: %v", err)
	}

	asset, err := svc.AddAsset(450, model.HostelAssetBed, "BED-450-01", "operational")
	if err != nil {
		t.Fatalf("failed to add asset: %v", err)
	}

	// 1. Edit Room Details (change block name and room number to 455)
	updatedRoom, err := svc.UpdateRoom(450, 455, "Block 3")
	if err != nil {
		t.Fatalf("failed to update room: %v", err)
	}
	if updatedRoom.RoomNumber != 455 || updatedRoom.BlockName != "Block 3" || updatedRoom.Floor != 3 {
		t.Errorf("expected room 455 in Block 3 on floor 3, got %d in %s on floor %d", updatedRoom.RoomNumber, updatedRoom.BlockName, updatedRoom.Floor)
	}

	// 2. Edit Asset Serial & Condition
	updatedAsset, err := svc.UpdateAsset(455, asset.ID, "BED-455-01", "maintenance_needed")
	if err != nil {
		t.Fatalf("failed to update asset: %v", err)
	}
	if updatedAsset.SerialNumber != "BED-455-01" || updatedAsset.Condition != "maintenance_needed" {
		t.Errorf("expected updated asset BED-455-01 with maintenance_needed, got %s / %s", updatedAsset.SerialNumber, updatedAsset.Condition)
	}

	// 3. Serial validation during update
	_, err = svc.UpdateAsset(455, asset.ID, "INVALID_SERIAL_TOO_LONG_12345", "operational")
	if err == nil {
		t.Errorf("expected invalid serial update to fail, but succeeded")
	}

	// 4. Duplicate serial during update must fail
	_, err = svc.UpdateAsset(455, asset.ID, "BED-101-01", "operational")
	if err == nil {
		t.Errorf("expected duplicate serial assignment to fail, but succeeded")
	}
}

func TestHostelQueriesAndRemoval(t *testing.T) {
	svc := NewHostelService(nil, nil)

	_, err := svc.CreateRoom(333, "Block 2")
	if err != nil {
		t.Fatalf("failed to create room 333: %v", err)
	}

	rooms, err := svc.GetRooms()
	if err != nil || len(rooms) == 0 {
		t.Fatalf("expected rooms, got %v", rooms)
	}

	fetched, err := svc.GetRoomByNumber(333)
	if err != nil || fetched.RoomNumber != 333 {
		t.Fatalf("expected room 333, got %v", fetched)
	}

	// Non-existent room
	_, err = svc.GetRoomByNumber(998)
	if err == nil {
		t.Fatalf("expected error for non-existent room 998")
	}

	asset, err := svc.AddAsset(333, "fan", "FAN-333-01", "good")
	if err != nil {
		t.Fatalf("failed to add fan: %v", err)
	}

	err = svc.RemoveAsset(333, asset.ID)
	if err != nil {
		t.Fatalf("failed to remove asset: %v", err)
	}

	// Remove non-existent asset
	err = svc.RemoveAsset(333, "non-existent-id")
	if err == nil {
		t.Fatalf("expected error removing non-existent asset")
	}
}

func TestHostelFloorDerivation(t *testing.T) {
	cases := []struct {
		roomNum  int
		expected int
	}{
		{101, 0},
		{150, 0},
		{199, 0},
		{201, 1},
		{204, 1},
		{299, 1},
		{301, 2},
		{305, 2},
		{399, 2},
		{401, 3},
		{402, 3},
		{499, 3},
		{501, 4},
		{550, 4},
		{599, 4},
	}

	for _, tc := range cases {
		actual := model.DeriveFloor(tc.roomNum)
		if actual != tc.expected {
			t.Errorf("DeriveFloor(%d): expected floor %d, got %d", tc.roomNum, tc.expected, actual)
		}
	}
}
