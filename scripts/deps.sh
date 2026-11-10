#!/usr/bin/env bash
# ==============================================================================
# scripts/deps.sh - Install repository dependencies
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Ensure flutter is discoverable
if ! command -v flutter >/dev/null 2>&1; then
  if [ -d "$HOME/.local/share/flutter/bin" ]; then
    export PATH="$HOME/.local/share/flutter/bin:$PATH"
  fi
fi

echo "==> [deps] Checking toolchains..."
command -v go >/dev/null 2>&1 || { echo "[error] Go is required but not installed."; exit 1; }
command -v flutter >/dev/null 2>&1 || { echo "[error] Flutter is required but not found in PATH or ~/.local/share/flutter/bin."; exit 1; }

echo "==> [deps] Installing Go backend dependencies..."
cd "$ROOT_DIR/backend"
go mod download
go mod tidy
echo "[deps] Go backend dependencies ready."

echo "==> [deps] Installing Flutter client dependencies..."
cd "$ROOT_DIR/client"
flutter pub get
echo "[deps] Flutter client dependencies ready."

echo "[deps] All dependencies installed successfully."
