#!/usr/bin/env bash
# ==============================================================================
# scripts/dev.sh - Start local development servers
# Usage:
#   ./script.sh dev                          # Start infra, backend, and native Flutter client
#   ./script.sh dev --no-app, --backend-only # Start only backend server
#   ./script.sh dev --web                    # Start backend and Flutter web client
#   ./script.sh dev --desktop, --linux       # Start backend and Flutter Linux client
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Ensure flutter is discoverable
if ! command -v flutter >/dev/null 2>&1; then
  if [ -d "$HOME/.local/share/flutter/bin" ]; then
    export PATH="$HOME/.local/share/flutter/bin:$PATH"
  fi
fi

if [ "${1:-}" = "help" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "Usage: ./script.sh dev [options]"
  echo "Options:"
  echo "  --no-app, --backend-only   Run only the Go backend server"
  echo "  --web                      Launch Flutter web client in Chrome"
  echo "  --desktop, --linux         Launch Flutter native Linux client (default)"
  exit 0
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

# 2. Deterministic Port Cleanup
APP_PORT="${PORT:-8080}"
PID=$(lsof -ti :"$APP_PORT" 2>/dev/null || true)
if [ -n "$PID" ]; then
  echo "==> [dev] Port $APP_PORT in use by PID $PID. Freeing port..."
  kill -9 "$PID" 2>/dev/null || true
fi

echo "==> [dev] Starting CampusManagement Go backend on http://localhost:$APP_PORT..."
cd "$ROOT_DIR/backend"
go run ./cmd/server &
BACKEND_PID=$!

# Wait briefly for server to bind port
sleep 1

echo "=================================================================="
echo "  CampusManagement Platform is running in dev mode!"
echo "  Backend API: http://localhost:$APP_PORT"
echo "  Health:      http://localhost:$APP_PORT/api/health"
echo "  Delta Sync:  http://localhost:$APP_PORT/api/v1/sync"
echo "  Web Portal:  http://localhost:$APP_PORT/"
echo "=================================================================="

# By default, launch the Flutter client unless --no-app or --backend-only is requested
LAUNCH_APP=true
CLIENT_DEVICE="linux"

for arg in "$@"; do
  case "$arg" in
    --no-app|--backend-only)
      LAUNCH_APP=false
      ;;
    --web)
      CLIENT_DEVICE="chrome"
      ;;
    --desktop|--linux)
      CLIENT_DEVICE="linux"
      ;;
  esac
done

if [ "$LAUNCH_APP" = true ]; then
  echo "==> [dev] Launching Flutter client (target: $CLIENT_DEVICE)..."
  cd "$ROOT_DIR/client"
  flutter run -d "$CLIENT_DEVICE"
else
  wait "$BACKEND_PID"
fi
