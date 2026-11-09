#!/usr/bin/env bash
# ==============================================================================
# scripts/check.sh - Run static analyzers and typecheckers
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Ensure flutter is discoverable
if ! command -v flutter >/dev/null 2>&1; then
  if [ -d "$HOME/.local/share/flutter/bin" ]; then
    export PATH="$HOME/.local/share/flutter/bin:$PATH"
  fi
fi

echo "==> [check] Running Go static analysis (go vet)..."
cd "$ROOT_DIR/backend"
go vet ./...

echo "==> [check] Running Flutter static analysis (flutter analyze)..."
cd "$ROOT_DIR/client"
flutter analyze

echo "[check] All Go and Flutter checks passed cleanly."
