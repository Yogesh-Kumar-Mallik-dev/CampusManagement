package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"campus/backend/internal/cache"
	"campus/backend/internal/database"
	"campus/backend/internal/model"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	redisAddr := os.Getenv("REDIS_ADDR")
	if redisAddr == "" {
		redisAddr = "localhost:6379"
	}

	// 1. Initialize Redis Store with safe fallback
	redisStore := cache.NewRedisStore(redisAddr, "", 0)
	cacheManager := cache.NewResilientManager(redisStore)

	// 2. Initialize PostgreSQL with strictly capped connection pool
	dbConfig := database.Config{
		Host:     "localhost",
		Port:     5432,
		User:     "campus_user",
		Password: "campus_password",
		DBName:   "campus_db",
		MaxConns: 30,
		MinConns: 5,
	}
	_, err := database.ConnectPostgres(dbConfig)
	if err != nil {
		log.Printf("[Warning] Database startup check: %v (continuing, will retry on request)", err)
	}

	// 3. Define HTTP Handlers
	mux := http.NewServeMux()

	// Health check endpoint
	mux.HandleFunc("/api/health", func(w http.ResponseWriter, r *http.Request) {
		status := map[string]interface{}{
			"status":      "ok",
			"timestamp":   time.Now().UTC(),
			"cache_ready": redisStore.IsAvailable(),
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(status)
	})

	// Sample Delta Sync Endpoint protected by Resilient Cache + Singleflight
	mux.HandleFunc("/api/v1/sync", func(w http.ResponseWriter, r *http.Request) {
		sinceParam := r.URL.Query().Get("since")
		cacheKey := fmt.Sprintf("sync:global:%s", sinceParam)

		data, err := cacheManager.FetchOrCompute(r.Context(), cacheKey, 3*time.Minute, func(ctx context.Context) ([]byte, error) {
			// In production, this queries PostgreSQL: WHERE updated_at > $1
			resp := model.DeltaSyncResponse{
				ServerTime: time.Now().UTC(),
				Notices: []model.Notice{
					{
						BaseSyncModel: model.BaseSyncModel{
							ID:        "notice-1",
							CreatedAt: time.Now().UTC().Add(-2 * time.Hour),
							UpdatedAt: time.Now().UTC().Add(-2 * time.Hour),
							IsDeleted: false,
						},
						Title:       "Fall Semester Registration Open",
						Content:     "Portal is active for course enrollment until next Friday.",
						Category:    "Academic",
						Publisher:   "Registrar Office",
						PublishedAt: time.Now().UTC().Add(-2 * time.Hour),
					},
				},
				Timetables: []model.TimetableEntry{},
			}
			return json.Marshal(resp)
		})

		if err != nil {
			http.Error(w, fmt.Sprintf("Error fetching data: %v", err), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write(data)
	})

	server := &http.Server{
		Addr:         ":" + port,
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	log.Printf("🚀 Campus Management Backend running on http://localhost:%s", port)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Server stopped: %v", err)
	}
}
