#!/usr/bin/env bash
# ==============================================================================
# scripts/check.sh - Run static analyzers and typecheckers
# Usage:
#   ./script.sh check              # Run both Go vet and Flutter analyze
#   ./script.sh check backend      # Run only Go vet
#   ./script.sh check client       # Run only Flutter analyze
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

case "$TARGET" in
  backend|go)
    echo "==> [check] Running Go static analysis (go vet)..."
    cd "$ROOT_DIR/backend"
    go vet ./...
    echo "[check] Go static analysis passed cleanly."
    ;;
  client|flutter|frontend)
    echo "==> [check] Running Flutter static analysis (flutter analyze)..."
    cd "$ROOT_DIR/client"
    flutter analyze
    echo "[check] Flutter static analysis passed cleanly."
    ;;
  all)
    echo "==> [check] Running Go static analysis (go vet)..."
    cd "$ROOT_DIR/backend"
    go vet ./...

    echo "==> [check] Running Flutter static analysis (flutter analyze)..."
    cd "$ROOT_DIR/client"
    flutter analyze

    echo "[check] All Go and Flutter checks passed cleanly."
    ;;
  help|--help|-h)
    echo "Usage: ./script.sh check [all|backend|client]"
    exit 0
    ;;
  *)
    echo "Unknown check target: $TARGET"
    echo "Usage: ./script.sh check [all|backend|client]"
    exit 1
    ;;
esac
