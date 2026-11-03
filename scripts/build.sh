#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/module-cache"

swift build -c release -debug-info-format none --disable-sandbox --cache-path "$PROJECT_DIR/.build/cache"
BIN_DIR="$(swift build -c release --disable-sandbox --cache-path "$PROJECT_DIR/.build/cache" --show-bin-path)"
APP_DIR="$PROJECT_DIR/build/Eye Care.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/EyeCare" "$APP_DIR/Contents/MacOS/EyeCare"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
swift "$PROJECT_DIR/scripts/GenerateIcon.swift" "$APP_DIR/Contents/Resources"
codesign --force --sign - --identifier local.eyecare.app "$APP_DIR"
printf '\nBuilt: %s\nOpen with: open "%s"\n' "$APP_DIR" "$APP_DIR"
