package handler

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

func setupTestHostelHandler() *HostelHandler {
	svc := service.NewHostelService(nil, nil)
	return NewHostelHandler(svc)
}

func TestHostelHandlerEndpoints(t *testing.T) {
	h := setupTestHostelHandler()

	// 1. GET /api/v1/hostel/rooms
	req := httptest.NewRequest(http.MethodGet, "/api/v1/hostel/rooms", nil)
	rec := httptest.NewRecorder()
	h.HandleRooms(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d", rec.Code)
	}

	var rooms []model.HostelRoom
	if err := json.NewDecoder(rec.Body).Decode(&rooms); err != nil {
		t.Fatalf("failed to decode rooms: %v", err)
	}
	if len(rooms) == 0 {
		t.Fatalf("expected seeded rooms, got 0")
	}

	// 2. POST /api/v1/hostel/rooms (Valid room number 505)
	createBody := map[string]interface{}{
		"room_number": 505,
		"block_name":  "Aryabhatta Block",
	}
	bodyBytes, _ := json.Marshal(createBody)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/hostel/rooms", bytes.NewReader(bodyBytes))
	rec = httptest.NewRecorder()
	h.HandleRooms(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created for room 505, got %d: %s", rec.Code, rec.Body.String())
	}

	// 3. POST /api/v1/hostel/rooms (Invalid room number 99)
	invalidBody := map[string]interface{}{
		"room_number": 99,
		"block_name":  "Aryabhatta Block",
	}
	bodyBytes, _ = json.Marshal(invalidBody)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/hostel/rooms", bytes.NewReader(bodyBytes))
	rec = httptest.NewRecorder()
	h.HandleRooms(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 Bad Request for room 99, got %d", rec.Code)
	}

	// 4. POST /api/v1/hostel/rooms/assets (Valid asset with <= 14 char serial)
	assetBody := map[string]interface{}{
		"room_number":   505,
		"asset_type":    "bed",
		"serial_number": "BED-505-01",
		"condition":     "operational",
	}
	bodyBytes, _ = json.Marshal(assetBody)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/hostel/rooms/assets", bytes.NewReader(bodyBytes))
	rec = httptest.NewRecorder()
	h.HandleAssets(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created for asset, got %d: %s", rec.Code, rec.Body.String())
	}

	// 5. POST /api/v1/hostel/rooms/assets (Invalid serial > 14 chars)
	longSerialBody := map[string]interface{}{
		"room_number":   505,
		"asset_type":    "fan",
		"serial_number": "FAN-505-LONG-SERIAL-15",
		"condition":     "operational",
	}
	bodyBytes, _ = json.Marshal(longSerialBody)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/hostel/rooms/assets", bytes.NewReader(bodyBytes))
	rec = httptest.NewRecorder()
	h.HandleAssets(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 Bad Request for serial > 14 chars, got %d", rec.Code)
	}

	// 6. POST /api/v1/hostel/rooms/occupants (Assign occupant)
	occBody := map[string]interface{}{
		"room_number":   505,
		"user_id":       "u-505-1",
		"campus_handle": "siddharth_2025_btech",
		"name":          "Siddharth Rao",
	}
	bodyBytes, _ = json.Marshal(occBody)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/hostel/rooms/occupants", bytes.NewReader(bodyBytes))
	rec = httptest.NewRecorder()
	h.HandleOccupants(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created for occupant, got %d: %s", rec.Code, rec.Body.String())
	}

	// 7. DELETE /api/v1/hostel/rooms/occupants
	req = httptest.NewRequest(http.MethodDelete, "/api/v1/hostel/rooms/occupants?room_number=505&user_id=u-505-1", nil)
	rec = httptest.NewRecorder()
	h.HandleOccupants(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 OK for removing occupant, got %d: %s", rec.Code, rec.Body.String())
	}
}
