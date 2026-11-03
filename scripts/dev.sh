#!/usr/bin/env bash
# ==============================================================================
# scripts/dev.sh - Start local development servers
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Ensure flutter is discoverable
if ! command -v flutter >/dev/null 2>&1; then
  if [ -d "$HOME/.local/share/flutter/bin" ]; then
    export PATH="$HOME/.local/share/flutter/bin:$PATH"
  fi
fi

cleanup() {
  echo ""
  echo "==> [dev] Shutting down background services..."
  kill $(jobs -p) 2>/dev/null || true
  exit 0
}

trap cleanup SIGINT SIGTERM EXIT

# 1. Ensure docker infrastructure is running
if [ -f "$ROOT_DIR/scripts/envi.sh" ]; then
  "$ROOT_DIR/scripts/envi.sh"
fi

# Load environment variables
if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
fi

# 2. Deterministic Port Cleanup (Port 8080)
for PORT in 8080; do
  PID=$(lsof -ti :$PORT 2>/dev/null || true)
  if [ -n "$PID" ]; then
    echo "==> [dev] Port $PORT in use by PID $PID. Freeing port..."
    kill -9 $PID 2>/dev/null || true
  fi
done

echo "==> [dev] Starting CampusManagement Go backend on http://localhost:8080..."
cd "$ROOT_DIR/backend"
go run ./cmd/server &
BACKEND_PID=$!

echo "=================================================================="
echo "  🏛️  CampusManagement Platform is running in dev mode!"
echo "  Backend API: http://localhost:8080"
echo "  Health:      http://localhost:8080/api/health"
echo "  Delta Sync:  http://localhost:8080/api/v1/sync"
echo ""
echo "  To launch the Flutter client:"
echo "    ./script.sh app run       (Native Linux Desktop)"
echo "    ./script.sh app web       (Google Chrome)"
echo "=================================================================="

# If --client or --app flag is passed, also launch the flutter app in background
if [[ "${1:-}" == "--client" || "${1:-}" == "--app" ]]; then
  echo "==> [dev] Launching Flutter client..."
  cd "$ROOT_DIR/client"
  flutter run -d linux &
fi

wait
