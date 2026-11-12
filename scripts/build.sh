#!/usr/bin/env bash
# ==============================================================================
# scripts/build.sh - Compile production assets and binaries
# Usage:
#   ./script.sh build              # Build both Go server binary and Flutter web bundle
#   ./script.sh build backend      # Build only Go server binary (backend/bin/server)
#   ./script.sh build web          # Build Flutter Web production bundle
#   ./script.sh build linux        # Build Flutter Linux native desktop release
#   ./script.sh build apk          # Build Flutter Android APK release
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
shift || true

build_backend() {
  echo "==> [build] Compiling Go backend binary..."
  cd "$ROOT_DIR/backend"
  mkdir -p bin
  go build -o bin/server ./cmd/server/main.go
  echo "[build] Go server binary built: backend/bin/server"
}

build_web() {
  echo "==> [build] Building Flutter web production bundle..."
  cd "$ROOT_DIR/client"
  flutter build web --release "$@"
  echo "[build] Flutter web bundle built: client/build/web"
}

build_linux() {
  echo "==> [build] Building Flutter Linux native desktop release..."
  cd "$ROOT_DIR/client"
  flutter build linux --release "$@"
  echo "[build] Flutter Linux desktop bundle built: client/build/linux/x64/release/bundle"
}

build_apk() {
  echo "==> [build] Building Flutter Android APK release..."
  cd "$ROOT_DIR/client"
  flutter build apk --release "$@"
  echo "[build] Flutter Android APK built: client/build/app/outputs/flutter-apk"
}

case "$TARGET" in
  backend|go|server)
    build_backend
    ;;
  web)
    build_web "$@"
    ;;
  desktop|linux)
    build_linux "$@"
    ;;
  apk|android)
    build_apk "$@"
    ;;
  all)
    build_backend
    build_web "$@"
    echo "[build] All production artifacts compiled successfully."
    ;;
  help|--help|-h)
    echo "Usage: ./script.sh build [all|backend|web|linux|apk]"
    exit 0
    ;;
  *)
    echo "Unknown build target: $TARGET"
    echo "Usage: ./script.sh build [all|backend|web|linux|apk]"
    exit 1
    ;;
esac
