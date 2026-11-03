#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
RENDER_DIR="$(mktemp -d)"
trap 'rm -rf "$RENDER_DIR"' EXIT
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/clang-cache"
swiftc -emit-library -emit-module -module-name EyeCareCore Sources/EyeCareCore/*.swift \
    -emit-module-path "$RENDER_DIR/EyeCareCore.swiftmodule" -o "$RENDER_DIR/libEyeCareCore.dylib"
swiftc -parse-as-library -I "$RENDER_DIR" -L "$RENDER_DIR" -lEyeCareCore \
    -Xlinker -rpath -Xlinker "$RENDER_DIR" \
    Sources/EyeCare/AppModel.swift Sources/EyeCare/Notifications.swift Sources/EyeCare/PopoverView.swift \
    scripts/CaptureScreenshots.swift -o "$RENDER_DIR/capture"
"$RENDER_DIR/capture" "$RENDER_DIR/frames"
mkdir -p docs/images
cp "$RENDER_DIR/frames/today-light.png" "$RENDER_DIR/frames/today-dark.png" docs/images/
python3 - "$RENDER_DIR/frames" <<'PY'
from pathlib import Path
import sys
from PIL import Image
folder = Path(sys.argv[1])
names = ['today-dark', 'rest-20', 'rest-15', 'rest-10', 'rest-5', 'rest-1', 'rest-complete']
frames = [Image.open(folder / (name + '.png')).convert('RGB').resize((348, 590)) for name in names]
frames[0].save('docs/images/rest-demo.gif', save_all=True, append_images=frames[1:],
               duration=[1600, 700, 700, 700, 700, 700, 1800], loop=0, disposal=2)
PY
