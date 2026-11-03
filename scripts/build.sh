#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/module-cache"

UNIVERSAL=false
APP_DIR="$PROJECT_DIR/build/Eye Care.app"
SIGNING_IDENTITY="-"
while [ "$#" -gt 0 ]; do
    case "$1" in
        --universal) UNIVERSAL=true; shift ;;
        --output) APP_DIR="${2:?Missing app output path}"; shift 2 ;;
        --sign) SIGNING_IDENTITY="${2:?Missing signing identity}"; shift 2 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
    esac
done

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
if [ "$UNIVERSAL" = true ]; then
    BINARIES=()
    for ARCH in arm64 x86_64; do
        SCRATCH_DIR="$PROJECT_DIR/.build/universal-$ARCH"
        swift build -c release -debug-info-format none --disable-sandbox --cache-path "$PROJECT_DIR/.build/cache" \
            --scratch-path "$SCRATCH_DIR" --triple "$ARCH-apple-macosx14.0"
        BIN_DIR="$(swift build -c release -debug-info-format none --disable-sandbox --cache-path "$PROJECT_DIR/.build/cache" \
            --scratch-path "$SCRATCH_DIR" --triple "$ARCH-apple-macosx14.0" --show-bin-path)"
        BINARIES+=("$BIN_DIR/EyeCare")
    done
    lipo -create "${BINARIES[@]}" -output "$APP_DIR/Contents/MacOS/EyeCare"
    for ARCH in arm64 x86_64; do
        lipo "$APP_DIR/Contents/MacOS/EyeCare" -verify_arch "$ARCH"
    done
else
    swift build -c release -debug-info-format none --disable-sandbox --cache-path "$PROJECT_DIR/.build/cache"
    BIN_DIR="$(swift build -c release -debug-info-format none --disable-sandbox --cache-path "$PROJECT_DIR/.build/cache" --show-bin-path)"
    cp "$BIN_DIR/EyeCare" "$APP_DIR/Contents/MacOS/EyeCare"
fi

cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
swift "$PROJECT_DIR/scripts/GenerateIcon.swift" "$APP_DIR/Contents/Resources"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_DIR/Contents/Info.plist")"
if [ "$SIGNING_IDENTITY" = "-" ]; then
    codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_DIR"
else
    codesign --force --sign "$SIGNING_IDENTITY" --identifier "$BUNDLE_ID" \
        --options runtime --timestamp "$APP_DIR"
fi
codesign --verify --strict "$APP_DIR"
printf '\nBuilt: %s\nOpen with: open "%s"\n' "$APP_DIR" "$APP_DIR"
