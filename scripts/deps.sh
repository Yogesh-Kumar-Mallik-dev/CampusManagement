#!/usr/bin/env bash
# ==============================================================================
# scripts/deps.sh - Install repository dependencies
# Usage:
#   ./script.sh deps              # Install both Go and Flutter dependencies
#   ./script.sh deps backend      # Install only Go module dependencies
#   ./script.sh deps client       # Install only Flutter pub dependencies
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Ensure flutter is discoverable
if ! command -v flutter >/dev/null 2>&1; then
  if [ -d "$HOME/.local/share/flutter/bin" ]; then
    export PATH="$HOME/.local/share/flutter/bin:$PATH"
  fi
fi

TARGET="${1:-all}"

install_go_deps() {
  command -v go >/dev/null 2>&1 || { echo "[error] Go is required but not installed."; exit 1; }
  echo "==> [deps] Installing Go backend dependencies..."
  cd "$ROOT_DIR/backend"
  go mod download
  go mod tidy
  echo "[deps] Go backend dependencies ready."
}

install_flutter_deps() {
  command -v flutter >/dev/null 2>&1 || { echo "[error] Flutter is required but not found in PATH or ~/.local/share/flutter/bin."; exit 1; }
  echo "==> [deps] Installing Flutter client dependencies..."
  cd "$ROOT_DIR/client"
  flutter pub get
  echo "[deps] Flutter client dependencies ready."
}

case "$TARGET" in
  backend|go)
    install_go_deps
    ;;
  client|flutter|frontend)
    install_flutter_deps
    ;;
  all)
    install_go_deps
    install_flutter_deps
    echo "[deps] All dependencies installed successfully."
    ;;
  help|--help|-h)
    echo "Usage: ./script.sh deps [all|backend|client]"
    exit 0
    ;;
  *)
    echo "Unknown deps target: $TARGET"
    echo "Usage: ./script.sh deps [all|backend|client]"
    exit 1
    ;;
esac
