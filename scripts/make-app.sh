#!/usr/bin/env bash
set -euo pipefail

# Build AgentDictate.app from the swift-build executable.
# Usage: scripts/make-app.sh [debug|release]

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/.build/$CONFIG"
EXEC="$BUILD_DIR/AgentDictate"
APP="$ROOT/.build/AgentDictate.app"
INFO_PLIST="$ROOT/AgentDictate/Info.plist"

if [ ! -x "$EXEC" ]; then
    echo "Executable not found at $EXEC. Run 'swift build -c $CONFIG' first." >&2
    exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources/Fonts"

cp "$EXEC" "$APP/Contents/MacOS/AgentDictate"

if [ -d "$ROOT/AgentDictate/Resources/Fonts" ]; then
    cp "$ROOT/AgentDictate/Resources/Fonts/"*.ttf "$APP/Contents/Resources/Fonts/" 2>/dev/null || true
fi

# Substitute build-setting placeholders xcodegen left in Info.plist with literal values.
python3 - "$INFO_PLIST" "$APP/Contents/Info.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as f:
    data = plistlib.load(f)
subs = {
    '$(DEVELOPMENT_LANGUAGE)': 'en',
    '$(EXECUTABLE_NAME)': 'AgentDictate',
    '$(PRODUCT_BUNDLE_IDENTIFIER)': 'com.luzivog.agentdictate',
    '$(PRODUCT_NAME)': 'AgentDictate',
    '$(MARKETING_VERSION)': '0.1.0',
    '$(CURRENT_PROJECT_VERSION)': '1',
    '$(MACOSX_DEPLOYMENT_TARGET)': '13.0',
}
def walk(o):
    if isinstance(o, dict):
        return {k: walk(v) for k, v in o.items()}
    if isinstance(o, list):
        return [walk(x) for x in o]
    if isinstance(o, str):
        for k, v in subs.items():
            o = o.replace(k, v)
        return o
    return o
data = walk(data)
with open(sys.argv[2], 'wb') as f:
    plistlib.dump(data, f)
PY

# Use a stable identifier so the codesign signature is reproducible across
# rebuilds — this prevents macOS TCC from treating each new build as a new
# app and re-prompting for Input Monitoring / Accessibility every time.
codesign --force --deep --sign - --identifier com.luzivog.agentdictate "$APP" >/dev/null

echo "Built $APP"
