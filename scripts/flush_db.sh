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
APP_PORT="${PORT:-8080}"
PID=$(lsof -ti :"$APP_PORT" 2>/dev/null || true)
if [ -n "$PID" ]; then
  echo "==> [flush] Stopping backend server on port $APP_PORT (PID $PID)..."
  kill -9 "$PID" 2>/dev/null || true
fi

# 2. Flush Redis cache (strictly targeting campus_redis container or port 6380)
echo "==> [flush] Flushing campus_redis cache..."
if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' | grep -q '^campus_redis$'; then
  docker exec campus_redis redis-cli flushall 2>/dev/null || true
elif command -v redis-cli >/dev/null 2>&1; then
  redis-cli -p "${REDIS_PORT:-6380}" flushall 2>/dev/null || true
fi

# 3. Reset PostgreSQL campus_db schema
echo "==> [flush] Resetting PostgreSQL campus_db schema..."
PG_USER="${POSTGRES_USER:-campus_user}"
PG_DB="${POSTGRES_DB:-campus_db}"
PG_PORT="${POSTGRES_PORT:-5435}"
PG_HOST="${POSTGRES_HOST:-localhost}"

if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' | grep -q '^campus_postgres$'; then
  docker exec -i campus_postgres psql -U "$PG_USER" -d "$PG_DB" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO $PG_USER;" 2>/dev/null || true
  if [ -f "$ROOT_DIR/backend/internal/database/schema.sql" ]; then
    echo "==> [flush] Re-applying schema.sql..."
    docker exec -i campus_postgres psql -U "$PG_USER" -d "$PG_DB" < "$ROOT_DIR/backend/internal/database/schema.sql" 2>/dev/null || true
  fi
elif command -v psql >/dev/null 2>&1; then
  psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO $PG_USER;" 2>/dev/null || true
  if [ -f "$ROOT_DIR/backend/internal/database/schema.sql" ]; then
    echo "==> [flush] Re-applying schema.sql..."
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" < "$ROOT_DIR/backend/internal/database/schema.sql" 2>/dev/null || true
  fi
fi

echo "[flush] PostgreSQL and Redis flushed successfully. Clean-slate ready."
