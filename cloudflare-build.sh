#!/usr/bin/env bash
# Cloudflare Pages build script.
#
# The Pages build image has no Flutter SDK, so this bootstraps one (shallow
# clone of the stable channel) and then builds the web release. Configure the
# Pages project with:
#   Build command:          bash cloudflare-build.sh
#   Build output directory: build/web
set -euo pipefail

FLUTTER_DIR="${FLUTTER_DIR:-$PWD/.flutter-sdk}"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "Bootstrapping Flutter (stable) into $FLUTTER_DIR…"
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

flutter --version
flutter config --no-analytics >/dev/null 2>&1 || true
flutter pub get
flutter build web --release

echo "Build complete: build/web"
