#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
UNSIGNED=false
case "${1:-}" in
    --unsigned) UNSIGNED=true ;;
    "") ;;
    *) printf 'Usage: bash scripts/release.sh [--unsigned]\n' >&2; exit 1 ;;
esac
if [ "$#" -gt 1 ]; then
    printf 'Usage: bash scripts/release.sh [--unsigned]\n' >&2
    exit 1
fi

if [ "$UNSIGNED" = false ]; then
    : "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to your Developer ID Application certificate name}"
    : "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your notarytool Keychain profile name}"
    case "$SIGNING_IDENTITY" in
        'Developer ID Application: '*) ;;
        *) printf 'A Developer ID Application certificate is required.\n' >&2; exit 1 ;;
    esac
    security find-identity -v -p codesigning | /usr/bin/grep -F -- "$SIGNING_IDENTITY" >/dev/null || {
        printf 'Signing identity not available in Keychain.\n' >&2; exit 1;
    }
    # Validate the stored credentials before starting the release build.
    xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" --output-format json >/dev/null
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
OUTPUT="$PROJECT_DIR/build/releases/v$VERSION"
mkdir -p "$OUTPUT"
WORK_DIR="$(mktemp -d "$OUTPUT/staging.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
APP_DIR="$WORK_DIR/Eye Care.app"
if [ "$UNSIGNED" = false ]; then
    bash scripts/build.sh --universal --output "$APP_DIR" --sign "$SIGNING_IDENTITY"
else
    bash scripts/build.sh --universal --output "$APP_DIR"
fi
cp LICENSE "$WORK_DIR/LICENSE"
cat > "$WORK_DIR/INSTALL.txt" <<'INSTALL'
Eye Care — macOS 14 or later, Apple Silicon and Intel

Move Eye Care.app to Applications and open it. Click the eye icon in the menu
bar; the app has no Dock icon. Enable notifications and launch at login from
Settings if desired. Keep one installed copy of the app.

Source, documentation, and issues: https://github.com/Refito/eye-care
License: MIT (see LICENSE)
INSTALL

if [ "$UNSIGNED" = true ]; then
    printf '\nDEVELOPMENT PREVIEW: This app is ad hoc signed, not Developer ID signed\nand not notarized. This archive is for packaging verification, not public release.\n' >> "$WORK_DIR/INSTALL.txt"
    ASSET="Eye-Care-$VERSION-universal-unsigned.zip"
else
    UPLOAD="$OUTPUT/notarization-upload.zip"
    ditto -c -k --keepParent "$APP_DIR" "$UPLOAD"
    xcrun notarytool submit "$UPLOAD" --keychain-profile "$NOTARY_PROFILE" \
        --wait --timeout 30m --output-format json > "$OUTPUT/notarization.json"
    STATUS="$(plutil -extract status raw -o - "$OUTPUT/notarization.json")"
    if [ "$STATUS" != Accepted ]; then
        printf 'Notarization did not succeed. See %s/notarization.json\n' "$OUTPUT" >&2
        exit 1
    fi
    xcrun stapler staple "$APP_DIR"
    xcrun stapler validate "$APP_DIR"
    codesign --verify --strict "$APP_DIR"
    spctl --assess --type execute --verbose=2 "$APP_DIR"
    ASSET="Eye-Care-$VERSION-universal.zip"
fi

# Package after stapling so the distributed app includes the notarization ticket.
ARCHIVE="$OUTPUT/$ASSET"
rm -f "$ARCHIVE"
ditto -c -k "$WORK_DIR" "$ARCHIVE"
(cd "$OUTPUT" && shasum -a 256 "$ASSET" > "$ASSET.sha256")
printf '\nRelease archive: %s\nChecksum: %s.sha256\n' "$ARCHIVE" "$ARCHIVE"
if [ "$UNSIGNED" = true ]; then
    printf 'Development preview only; signing and notarization are still required.\n'
fi
