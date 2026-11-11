#!/usr/bin/env bash
# ==============================================================================
# scripts/flush_db.sh - Flush databases and caches for clean-slate testing
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load environment variables if available
if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
fi

# 1. Stop any running backend server so in-memory cache is fully cleared
for PORT in 8080; do
  PID=$(lsof -ti :$PORT 2>/dev/null || true)
  if [ -n "$PID" ]; then
    echo "==> [flush] Stopping backend server on port $PORT (PID $PID)..."
    kill -9 $PID 2>/dev/null || true
  fi
done

# 2. Flush Redis cache (strictly targeting campus_redis container or port 6380)
echo "==> [flush] Flushing campus_redis cache..."
if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' | grep -q '^campus_redis$'; then
  docker exec campus_redis redis-cli flushall 2>/dev/null || true
elif command -v redis-cli >/dev/null 2>&1; then
  redis-cli -p "${REDIS_PORT:-6380}" flushall 2>/dev/null || true
fi

# 3. Reset PostgreSQL campus_db schema
echo "==> [flush] Resetting PostgreSQL campus_db schema..."
if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' | grep -q '^campus_postgres$'; then
  docker exec -i campus_postgres psql -U campus_user -d campus_db -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" 2>/dev/null || true
  if [ -f "$ROOT_DIR/backend/internal/database/schema.sql" ]; then
    echo "==> [flush] Re-applying schema.sql..."
    docker exec -i campus_postgres psql -U campus_user -d campus_db < "$ROOT_DIR/backend/internal/database/schema.sql" 2>/dev/null || true
  fi
fi

echo "[flush] PostgreSQL and Redis flushed successfully. Clean-slate ready."
