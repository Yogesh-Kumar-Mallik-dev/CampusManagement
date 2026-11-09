#!/usr/bin/env bash
# ==============================================================================
# scripts/build.sh - Compile production assets and binaries
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Ensure flutter is discoverable
if ! command -v flutter >/dev/null 2>&1; then
  if [ -d "$HOME/.local/share/flutter/bin" ]; then
    export PATH="$HOME/.local/share/flutter/bin:$PATH"
  fi
fi

echo "==> [build] Compiling Go backend binary..."
cd "$ROOT_DIR/backend"
mkdir -p bin
go build -o bin/server ./cmd/server/main.go
echo "[build] Go server binary built: backend/bin/server"

echo "==> [build] Building Flutter web production bundle..."
cd "$ROOT_DIR/client"
flutter build web --release
echo "[build] Flutter web bundle built: client/build/web"

echo "[build] All production artifacts compiled successfully."
