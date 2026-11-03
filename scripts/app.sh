#!/usr/bin/env bash
# ==============================================================================
# scripts/app.sh - Run, build, or test the native Flutter cross-platform client
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIENT_DIR="$ROOT_DIR/client"

# Ensure flutter is discoverable
if ! command -v flutter >/dev/null 2>&1; then
  if [ -d "$HOME/.local/share/flutter/bin" ]; then
    export PATH="$HOME/.local/share/flutter/bin:$PATH"
  fi
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ Flutter SDK not found in PATH or ~/.local/share/flutter/bin"
  exit 1
fi

SUBCOMMAND="${1:-run}"
shift || true

cd "$CLIENT_DIR"

case "$SUBCOMMAND" in
  run|desktop)
    echo "==> [app] Running Flutter native desktop client..."
    flutter run -d linux "$@"
    ;;
  web)
    echo "==> [app] Running Flutter web client in Chrome..."
    flutter run -d chrome "$@"
    ;;
  build)
    echo "==> [app] Building Flutter native Linux release bundle..."
    flutter build linux --release "$@"
    ;;
  build-web)
    echo "==> [app] Building Flutter Web production bundle..."
    flutter build web --release "$@"
    ;;
  apk)
    echo "==> [app] Building Flutter Android release APK..."
    flutter build apk --release "$@"
    ;;
  check|analyze)
    echo "==> [app] Running flutter analyze..."
    flutter analyze "$@"
    ;;
  test)
    echo "==> [app] Running flutter test..."
    flutter test "$@"
    ;;
  *)
    echo "Usage: ./script.sh app [run|web|desktop|build|build-web|apk|check|test]"
    exit 1
    ;;
esac
