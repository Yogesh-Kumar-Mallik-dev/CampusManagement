#!/usr/bin/env bash
# ==============================================================================
# scripts/uenvi.sh - 1-Click Environment Teardown
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "${1:-}" = "help" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "Usage: ./script.sh uenvi"
  echo "Tears down local Docker containers (campus_postgres, campus_redis)."
  exit 0
fi

# Load environment variables if available
if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
fi

if command -v docker >/dev/null 2>&1; then
  echo "==> [uenvi] Stopping and removing CampusManagement containers..."
  cd "$ROOT_DIR"
  docker compose down
  for CNAME in campus_postgres campus_redis; do
    if docker ps -a --format '{{.Names}}' | grep -Eq "^${CNAME}$"; then
      docker rm -f "$CNAME" >/dev/null 2>&1 || true
    fi
  done
  echo "[uenvi] Containers stopped and cleaned up."
else
  echo "[warning] [uenvi] Docker not found. No containers to stop."
fi
