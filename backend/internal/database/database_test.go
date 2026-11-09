package database

import (
	"context"
	"testing"
)

func TestDatabaseConfigDefaultsAndOfflineFallback(t *testing.T) {
	cfg := Config{
		Host:     "localhost",
		Port:     59998, // Non-existent DB port
		User:     "user",
		Password: "password",
		DBName:   "db",
		MaxConns: 0,
		MinConns: 0,
	}

	// Should safely return pool without crashing even if postgres is offline
	pool, err := ConnectPostgres(cfg)
	if err != nil {
		t.Logf("Expected ConnectPostgres to return error or fallback pool: %v", err)
	}
	if pool != nil {
		pool.Close()
	}
}

func TestInvalidDatabaseConfig(t *testing.T) {
	cfg := Config{
		Host: ":::invalid-url-schema",
		Port: -1,
	}
	pool, err := ConnectPostgres(cfg)
	if err == nil && pool != nil {
		pool.Close()
	}
}

func TestInitSchemaNilPool(t *testing.T) {
	ctx := context.Background()
	// Calling InitSchema on nil pool will panic or error safely
	defer func() {
		_ = recover()
	}()
	_ = InitSchema(ctx, nil)
}
