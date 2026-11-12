#!/usr/bin/env bash
# ==============================================================================
# scripts/envi.sh - 1-Click Environment Setup & Docker Infrastructure
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> [envi] Initializing environment configuration..."
if [ ! -f "$ROOT_DIR/.env" ]; then
  if [ -f "$ROOT_DIR/.env.example" ]; then
    cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
    echo "[envi] Created .env from .env.example"
  fi
fi

# Load environment variables
if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
fi

if command -v docker >/dev/null 2>&1; then
  echo "==> [envi] Starting PostgreSQL 16 and Redis 7 via Docker Compose..."
  cd "$ROOT_DIR"

  # Clean up any conflicting orphaned containers
  for CNAME in campus_postgres campus_redis; do
    if docker ps -a --format '{{.Names}}' | grep -Eq "^${CNAME}$"; then
      PROJ=$(docker inspect "$CNAME" --format '{{index .Config.Labels "com.docker.compose.project"}}' 2>/dev/null || true)
      if [ "$PROJ" != "campusmanagement" ] && [ "$PROJ" != "campus" ]; then
        echo "==> [envi] Cleaning up conflicting container $CNAME..."
        docker rm -f "$CNAME" >/dev/null 2>&1 || true
      fi
    fi
  done

  if docker compose up -d postgres redis; then
    echo "[envi] Infrastructure containers started successfully."
    
    # Wait briefly for PostgreSQL and Redis to be ready
    if docker ps --format '{{.Names}}' | grep -q '^campus_postgres$'; then
      for _ in {1..10}; do
        if docker exec campus_postgres pg_isready -U "${POSTGRES_USER:-campus_user}" -d "${POSTGRES_DB:-campus_db}" >/dev/null 2>&1; then
          break
        fi
        sleep 0.5
      done
    fi
  else
    echo "[warning] [envi] Docker compose encountered a non-fatal warning. Continuing if local services are active..."
  fi
else
  echo "[warning] [envi] Docker not found. Ensure PostgreSQL (${POSTGRES_PORT:-5435}) and Redis (${REDIS_PORT:-6380}) are running locally."
fi
