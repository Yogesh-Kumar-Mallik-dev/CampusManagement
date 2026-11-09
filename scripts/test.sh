#!/usr/bin/env bash
# ==============================================================================
# scripts/test.sh - Run test suites
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Ensure flutter is discoverable
if ! command -v flutter >/dev/null 2>&1; then
  if [ -d "$HOME/.local/share/flutter/bin" ]; then
    export PATH="$HOME/.local/share/flutter/bin:$PATH"
  fi
fi

echo "==> [test] Running Go backend test suite..."
cd "$ROOT_DIR/backend"
go test -v ./...

echo "==> [test] Running Flutter client test suite..."
cd "$ROOT_DIR/client"
if [ "$#" -gt 0 ]; then
  flutter test "$@"
else
  flutter test
fi

echo "[test] All backend and client test suites passed successfully."
