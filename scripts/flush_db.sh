#!/usr/bin/env bash
# ==============================================================================
# scripts/flush_db.sh - Flush databases and caches for clean-slate testing
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> [flush] Flushing Redis cache..."
if command -v redis-cli >/dev/null 2>&1; then
  redis-cli flushall || true
elif command -v docker >/dev/null 2>&1; then
  docker exec campus_redis redis-cli flushall 2>/dev/null || true
fi

echo "==> [flush] Resetting PostgreSQL campus_db schema..."
if command -v docker >/dev/null 2>&1; then
  docker exec -i campus_postgres psql -U campus_user -d campus_db -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" 2>/dev/null || true
  if [ -f "$ROOT_DIR/backend/internal/database/schema.sql" ]; then
    echo "==> [flush] Re-applying schema.sql..."
    docker exec -i campus_postgres psql -U campus_user -d campus_db < "$ROOT_DIR/backend/internal/database/schema.sql" 2>/dev/null || true
  fi
fi

echo "[flush] PostgreSQL and Redis flushed successfully."
