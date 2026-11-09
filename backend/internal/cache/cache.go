package cache

import (
	"context"
	"errors"
	"log"
	"sync"
	"time"

	"github.com/redis/go-redis/v9"
	"golang.org/x/sync/singleflight"
)

// Store defines the basic caching contract
type Store interface {
	Get(ctx context.Context, key string) ([]byte, error)
	Set(ctx context.Context, key string, val []byte, ttl time.Duration) error
	Delete(ctx context.Context, key string) error
	IsAvailable() bool
}

// RedisStore wraps Redis client with safe failure handling
type RedisStore struct {
	client *redis.Client
}

func NewRedisStore(addr, password string, db int) *RedisStore {
	rdb := redis.NewClient(&redis.Options{
		Addr:         addr,
		Password:     password,
		DB:           db,
		DialTimeout:  2 * time.Second,
		ReadTimeout:  1 * time.Second,
		WriteTimeout: 1 * time.Second,
		PoolSize:     20,
	})
	return &RedisStore{client: rdb}
}

func (r *RedisStore) IsAvailable() bool {
	if r == nil || r.client == nil {
		return false
	}
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()
	return r.client.Ping(ctx).Err() == nil
}

func (r *RedisStore) Get(ctx context.Context, key string) ([]byte, error) {
	if r == nil || r.client == nil {
		return nil, nil
	}
	if ctx == nil {
		ctx = context.Background()
	}
	val, err := r.client.Get(ctx, key).Bytes()
	if errors.Is(err, redis.Nil) {
		return nil, nil // Cache miss
	}
	if err != nil {
		// Log warning instead of crashing or stopping callers
		log.Printf("[Cache Warning] Redis Get failed for key %s: %v", key, err)
		return nil, nil // Treat transient cache failure as cache miss
	}
	return val, nil
}

func (r *RedisStore) Set(ctx context.Context, key string, val []byte, ttl time.Duration) error {
	if r == nil || r.client == nil {
		return nil
	}
	if ctx == nil {
		ctx = context.Background()
	}
	err := r.client.Set(ctx, key, val, ttl).Err()
	if err != nil {
		log.Printf("[Cache Warning] Redis Set failed for key %s: %v", key, err)
	}
	return nil
}

func (r *RedisStore) Delete(ctx context.Context, key string) error {
	if r == nil || r.client == nil {
		return nil
	}
	if ctx == nil {
		ctx = context.Background()
	}
	_ = r.client.Del(ctx, key).Err()
	return nil
}

// ResilientManager orchestrates caching + singleflight query deduplication
// so that cache flushes/restarts never overwhelm PostgreSQL.
type ResilientManager struct {
	store Store
	group singleflight.Group
}

func NewResilientManager(store Store) *ResilientManager {
	return &ResilientManager{
		store: store,
	}
}

// FetchOrCompute checks cache first; on cache miss (or if cache is offline),
// uses singleflight to collapse multiple concurrent requests into exactly 1 database query.
func (rm *ResilientManager) FetchOrCompute(
	ctx context.Context,
	key string,
	ttl time.Duration,
	compute func(ctx context.Context) ([]byte, error),
) ([]byte, error) {
	if ctx == nil {
		ctx = context.Background()
	}
	// 1. Try Cache
	if rm.store != nil {
		if data, err := rm.store.Get(ctx, key); err == nil && data != nil {
			return data, nil
		}
	}

	// 2. Cache miss or cache failure: Singleflight deduplication
	result, err, _ := rm.group.Do(key, func() (interface{}, error) {
		data, computeErr := compute(ctx)
		if computeErr != nil {
			return nil, computeErr
		}

		// Store in cache asynchronously without delaying the caller
		if rm.store != nil && len(data) > 0 {
			go func() {
				setCtx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
				defer cancel()
				_ = rm.store.Set(setCtx, key, data, ttl)
			}()
		}

		return data, nil
	})

	if err != nil {
		return nil, err
	}

	return result.([]byte), nil
}

// MemoryStore provides thread-safe in-memory caching for isolated tests and offline mode
type MemoryStore struct {
	mu   sync.RWMutex
	data map[string][]byte
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		data: make(map[string][]byte),
	}
}

func (m *MemoryStore) IsAvailable() bool {
	return m != nil
}

func (m *MemoryStore) Get(ctx context.Context, key string) ([]byte, error) {
	if m == nil {
		return nil, nil
	}
	m.mu.RLock()
	defer m.mu.RUnlock()
	val, ok := m.data[key]
	if !ok {
		return nil, nil
	}
	cp := make([]byte, len(val))
	copy(cp, val)
	return cp, nil
}

func (m *MemoryStore) Set(ctx context.Context, key string, val []byte, ttl time.Duration) error {
	if m == nil {
		return nil
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	cp := make([]byte, len(val))
	copy(cp, val)
	m.data[key] = cp
	return nil
}

func (m *MemoryStore) Delete(ctx context.Context, key string) error {
	if m == nil {
		return nil
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.data, key)
	return nil
}
