#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/module-cache"
# Some command-line-only Swift toolchains need the bundled Testing macro loaded explicitly.
TOOLCHAIN_DIR="$(cd "$(dirname "$(xcrun --find swiftc)")/.." && pwd)"
TEST_MACRO="$TOOLCHAIN_DIR/lib/swift/host/plugins/testing/libTestingMacros.dylib"
MACRO_FLAGS=()
if [ -f "$TEST_MACRO" ]; then
    MACRO_FLAGS=(-Xswiftc -load-plugin-library -Xswiftc "$TEST_MACRO")
fi
swift test --disable-sandbox --cache-path "$PROJECT_DIR/.build/cache" "${MACRO_FLAGS[@]}"
