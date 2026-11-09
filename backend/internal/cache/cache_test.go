package cache

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func TestMemoryStore(t *testing.T) {
	ctx := context.Background()
	store := NewMemoryStore()

	if !store.IsAvailable() {
		t.Fatal("expected MemoryStore to be available")
	}

	// 1. Get non-existent
	val, err := store.Get(ctx, "nonexistent")
	if err != nil || val != nil {
		t.Fatalf("expected nil for non-existent key, got %v, %v", val, err)
	}

	// 2. Set and Get
	err = store.Set(ctx, "key1", []byte("hello world"), time.Minute)
	if err != nil {
		t.Fatalf("set failed: %v", err)
	}

	val, err = store.Get(ctx, "key1")
	if err != nil || string(val) != "hello world" {
		t.Fatalf("unexpected get result: %s, %v", string(val), err)
	}

	// 3. Delete
	err = store.Delete(ctx, "key1")
	if err != nil {
		t.Fatalf("delete failed: %v", err)
	}

	val, err = store.Get(ctx, "key1")
	if err != nil || val != nil {
		t.Fatalf("expected nil after delete, got %v", val)
	}

	// 4. Nil store safe handling
	var nilStore *MemoryStore
	if nilStore.IsAvailable() {
		t.Fatal("expected nil store to not be available")
	}
	val, err = nilStore.Get(ctx, "k")
	if err != nil || val != nil {
		t.Fatal("expected nil, nil on nil store get")
	}
	_ = nilStore.Set(ctx, "k", []byte("v"), time.Minute)
	_ = nilStore.Delete(ctx, "k")
}

func TestResilientManagerFetchOrCompute(t *testing.T) {
	ctx := context.Background()
	store := NewMemoryStore()
	manager := NewResilientManager(store)

	var computeCount int32
	computeFn := func(c context.Context) ([]byte, error) {
		atomic.AddInt32(&computeCount, 1)
		return []byte("computed-value"), nil
	}

	// First call -> computes and caches
	val1, err := manager.FetchOrCompute(ctx, "cache-key", time.Minute, computeFn)
	if err != nil || string(val1) != "computed-value" {
		t.Fatalf("unexpected value: %s, %v", string(val1), err)
	}
	if atomic.LoadInt32(&computeCount) != 1 {
		t.Fatalf("expected computeCount=1, got %d", computeCount)
	}

	// Wait briefly for async cache set goroutine
	time.Sleep(50 * time.Millisecond)

	// Second call -> served from cache
	val2, err := manager.FetchOrCompute(ctx, "cache-key", time.Minute, computeFn)
	if err != nil || string(val2) != "computed-value" {
		t.Fatalf("unexpected value on second call: %s, %v", string(val2), err)
	}
	if atomic.LoadInt32(&computeCount) != 1 {
		t.Fatalf("expected computeCount to stay 1, got %d", computeCount)
	}

	// Error path
	expectedErr := errors.New("database failure")
	_, err = manager.FetchOrCompute(ctx, "error-key", time.Minute, func(c context.Context) ([]byte, error) {
		return nil, expectedErr
	})
	if !errors.Is(err, expectedErr) {
		t.Fatalf("expected error %v, got %v", expectedErr, err)
	}
}

func TestResilientManagerSingleflightDeduplication(t *testing.T) {
	ctx := context.Background()
	store := NewMemoryStore()
	manager := NewResilientManager(store)

	var computeCount int32
	var wg sync.WaitGroup

	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			val, err := manager.FetchOrCompute(ctx, "concurrent-key", time.Minute, func(c context.Context) ([]byte, error) {
				time.Sleep(20 * time.Millisecond) // Simulate slow query
				atomic.AddInt32(&computeCount, 1)
				return []byte("concurrent-result"), nil
			})
			if err != nil || string(val) != "concurrent-result" {
				t.Errorf("concurrent fetch failed: %v", err)
			}
		}()
	}

	wg.Wait()

	// Singleflight should collapse concurrent requests into 1 compute call
	if atomic.LoadInt32(&computeCount) > 2 {
		t.Fatalf("expected <= 2 computes due to singleflight, got %d", computeCount)
	}
}

func TestRedisStoreSafetyWhenOffline(t *testing.T) {
	// Points to dead port where no redis is running
	store := NewRedisStore("localhost:59999", "", 0)

	if store.IsAvailable() {
		t.Log("Note: Redis was unexpectedly online on port 59999")
	}

	ctx := context.Background()
	val, err := store.Get(ctx, "dummy")
	if err != nil || val != nil {
		t.Fatalf("expected nil data and nil error on offline get, got %v, %v", val, err)
	}

	err = store.Set(ctx, "dummy", []byte("val"), time.Minute)
	if err != nil {
		t.Fatalf("expected safe nil error on offline set, got %v", err)
	}

	err = store.Delete(ctx, "dummy")
	if err != nil {
		t.Fatalf("expected safe nil error on offline delete, got %v", err)
	}

	// Test nil redis store
	var nilStore *RedisStore
	if nilStore.IsAvailable() {
		t.Fatal("expected nil redis store to be unavailable")
	}
	_, _ = nilStore.Get(ctx, "k")
	_ = nilStore.Set(ctx, "k", []byte("v"), time.Minute)
	_ = nilStore.Delete(ctx, "k")
}
