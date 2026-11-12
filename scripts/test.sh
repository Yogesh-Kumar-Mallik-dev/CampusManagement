#!/usr/bin/env bash
# ==============================================================================
# scripts/test.sh - Run test suites
# Usage:
#   ./script.sh test                     # Run all test suites
#   ./script.sh test backend [args...]   # Run only Go backend tests
#   ./script.sh test client [args...]    # Run only Flutter client tests
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
    shift || true
    echo "==> [test] Running Go backend test suite..."
    cd "$ROOT_DIR/backend"
    if [ "$#" -gt 0 ]; then
      go test -v ./... "$@"
    else
      go test -v ./...
    fi
    echo "[test] Backend test suite passed successfully."
    ;;
  client|flutter|frontend)
    shift || true
    echo "==> [test] Running Flutter client test suite..."
    cd "$ROOT_DIR/client"
    if [ "$#" -gt 0 ]; then
      flutter test "$@"
    else
      flutter test
    fi
    echo "[test] Client test suite passed successfully."
    ;;
  all)
    echo "==> [test] Running Go backend test suite..."
    cd "$ROOT_DIR/backend"
    go test -v ./...

    echo "==> [test] Running Flutter client test suite..."
    cd "$ROOT_DIR/client"
    flutter test

    echo "[test] All backend and client test suites passed successfully."
    ;;
  help|--help|-h)
    echo "Usage: ./script.sh test [all|backend|client] [extra args...]"
    exit 0
    ;;
  *)
    # If the first argument is a file path or flag starting with -
    if [[ "$TARGET" == -* ]] || [[ "$TARGET" == *.dart ]]; then
      echo "==> [test] Running Flutter client test suite with args: $*..."
      cd "$ROOT_DIR/client"
      flutter test "$@"
      echo "[test] Client tests passed successfully."
    else
      echo "Unknown test target: $TARGET"
      echo "Usage: ./script.sh test [all|backend|client] [extra args...]"
      exit 1
    fi
    ;;
esac
