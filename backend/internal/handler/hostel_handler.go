package handler

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"campus/backend/internal/model"
	"campus/backend/internal/service"
)

type HostelHandler struct {
	hostelService *service.HostelService
}

func NewHostelHandler(svc *service.HostelService) *HostelHandler {
	return &HostelHandler{hostelService: svc}
}

// HandleRooms handles GET /api/v1/hostel/rooms and POST /api/v1/hostel/rooms
func (h *HostelHandler) HandleRooms(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	switch r.Method {
	case http.MethodGet:
		roomParam := r.URL.Query().Get("room")
		if roomParam != "" {
			num, err := strconv.Atoi(roomParam)
			if err != nil {
				http.Error(w, `{"error":"invalid room number format"}`, http.StatusBadRequest)
				return
			}
			room, err := h.hostelService.GetRoomByNumber(num)
			if err != nil {
				http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusNotFound)
				return
			}
			_ = json.NewEncoder(w).Encode(room)
			return
		}

		rooms, err := h.hostelService.GetRooms()
		if err != nil {
			http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
			return
		}

		floorParam := r.URL.Query().Get("floor")
		if floorParam != "" {
			floorNum, err := strconv.Atoi(floorParam)
			if err == nil {
				filtered := make([]model.HostelRoom, 0)
				for _, rm := range rooms {
					if rm.Floor == floorNum {
						filtered = append(filtered, rm)
					}
				}
				_ = json.NewEncoder(w).Encode(filtered)
				return
			}
		}

		_ = json.NewEncoder(w).Encode(rooms)

	case http.MethodPost:
		var req struct {
			RoomNumber int    `json:"room_number"`
			BlockName  string `json:"block_name"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error":"invalid request payload"}`, http.StatusBadRequest)
			return
		}

		room, err := h.hostelService.CreateRoom(req.RoomNumber, req.BlockName)
		if err != nil {
			http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
			return
		}

		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(room)

	case http.MethodPut:
		var req struct {
			OriginalRoomNumber int    `json:"original_room_number"`
			NewRoomNumber      int    `json:"new_room_number"`
			BlockName          string `json:"block_name"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error":"invalid request payload"}`, http.StatusBadRequest)
			return
		}
		if req.OriginalRoomNumber == 0 {
			req.OriginalRoomNumber = req.NewRoomNumber
		}
		room, err := h.hostelService.UpdateRoom(req.OriginalRoomNumber, req.NewRoomNumber, req.BlockName)
		if err != nil {
			http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
			return
		}
		_ = json.NewEncoder(w).Encode(room)

	default:
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
	}
}

// HandleAssets handles POST, PUT, DELETE /api/v1/hostel/rooms/assets
func (h *HostelHandler) HandleAssets(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	switch r.Method {
	case http.MethodPost:
		var req struct {
			RoomNumber   int    `json:"room_number"`
			AssetType    string `json:"asset_type"`
			SerialNumber string `json:"serial_number"`
			Condition    string `json:"condition"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error":"invalid request payload"}`, http.StatusBadRequest)
			return
		}

		asset, err := h.hostelService.AddAsset(req.RoomNumber, req.AssetType, req.SerialNumber, req.Condition)
		if err != nil {
			http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
			return
		}

		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(asset)

	case http.MethodPut:
		var req struct {
			RoomNumber   int    `json:"room_number"`
			AssetID      string `json:"asset_id"`
			SerialNumber string `json:"serial_number"`
			Condition    string `json:"condition"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error":"invalid request payload"}`, http.StatusBadRequest)
			return
		}

		asset, err := h.hostelService.UpdateAsset(req.RoomNumber, req.AssetID, req.SerialNumber, req.Condition)
		if err != nil {
			http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
			return
		}
		_ = json.NewEncoder(w).Encode(asset)

	case http.MethodDelete:
		roomParam := r.URL.Query().Get("room_number")
		assetID := r.URL.Query().Get("asset_id")

		if roomParam == "" || assetID == "" {
			var bodyReq struct {
				RoomNumber int    `json:"room_number"`
				AssetID    string `json:"asset_id"`
			}
			_ = json.NewDecoder(r.Body).Decode(&bodyReq)
			if bodyReq.RoomNumber != 0 {
				roomParam = strconv.Itoa(bodyReq.RoomNumber)
			}
			if bodyReq.AssetID != "" {
				assetID = bodyReq.AssetID
			}
		}

		num, err := strconv.Atoi(roomParam)
		if err != nil || assetID == "" {
			http.Error(w, `{"error":"missing or invalid room_number or asset_id"}`, http.StatusBadRequest)
			return
		}

		if err := h.hostelService.RemoveAsset(num, assetID); err != nil {
			http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
			return
		}

		_ = json.NewEncoder(w).Encode(map[string]interface{}{
			"success": true,
			"message": "asset successfully removed",
		})

	default:
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
	}
}

// HandleOccupants handles POST /api/v1/hostel/rooms/occupants and DELETE /api/v1/hostel/rooms/occupants
func (h *HostelHandler) HandleOccupants(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	switch r.Method {
	case http.MethodPost:
		var req struct {
			RoomNumber   int    `json:"room_number"`
			UserID       string `json:"user_id"`
			CampusHandle string `json:"campus_handle"`
			Name         string `json:"name"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error":"invalid request payload"}`, http.StatusBadRequest)
			return
		}

		occ, err := h.hostelService.AssignOccupant(req.RoomNumber, req.UserID, req.CampusHandle, req.Name)
		if err != nil {
			http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
			return
		}

		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(occ)

	case http.MethodDelete:
		roomParam := r.URL.Query().Get("room_number")
		identifier := r.URL.Query().Get("user_id")
		if identifier == "" {
			identifier = r.URL.Query().Get("campus_handle")
		}

		if roomParam == "" || identifier == "" {
			var bodyReq struct {
				RoomNumber int    `json:"room_number"`
				UserID     string `json:"user_id"`
			}
			_ = json.NewDecoder(r.Body).Decode(&bodyReq)
			if bodyReq.RoomNumber != 0 {
				roomParam = strconv.Itoa(bodyReq.RoomNumber)
			}
			if bodyReq.UserID != "" {
				identifier = bodyReq.UserID
			}
		}

		num, err := strconv.Atoi(roomParam)
		if err != nil || strings.TrimSpace(identifier) == "" {
			http.Error(w, `{"error":"missing or invalid room_number or user identifier"}`, http.StatusBadRequest)
			return
		}

		if err := h.hostelService.RemoveOccupant(num, identifier); err != nil {
			http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
			return
		}

		_ = json.NewEncoder(w).Encode(map[string]interface{}{
			"success": true,
			"message": "occupant successfully removed",
		})

	default:
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
	}
}
