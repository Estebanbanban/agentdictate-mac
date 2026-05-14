#!/usr/bin/env bash
# End-to-end QA script. Spins up a mock OpenAI server, drives AgentDictate via
# CGEvent injection, asserts on stderr logs + clipboard + TextEdit content.
# Run: scripts/qa-e2e.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="/tmp/agentdictate-qa.log"
MOCK_PID_FILE="/tmp/mock-openai.pid"
APP="$ROOT/.build/AgentDictate.app"

PASS=0
FAIL=0

cleanup() {
    pkill -f "AgentDictate.app/Contents/MacOS" 2>/dev/null || true
    if [ -f "$MOCK_PID_FILE" ]; then
        kill "$(cat "$MOCK_PID_FILE")" 2>/dev/null || true
        rm -f "$MOCK_PID_FILE"
    fi
}
trap cleanup EXIT

check() {
    local name="$1"
    local cond="$2"
    if [ "$cond" = "true" ]; then
        echo "  ✓ $name"
        PASS=$((PASS + 1))
    else
        echo "  ✗ $name"
        FAIL=$((FAIL + 1))
    fi
}

stderr_contains() {
    grep -q "$1" "$LOG" 2>/dev/null && echo true || echo false
}

# ──────────────── boot ────────────────

echo "[QA] killing stale processes…"
cleanup
sleep 1

echo "[QA] starting mock OpenAI server…"
python3 "$ROOT/tests-no-xcode/mocks/mock-openai.py" > /tmp/mock-openai.log 2>&1 &
echo $! > "$MOCK_PID_FILE"
sleep 1

echo "[QA] setting default ⌥Space binding…"
HEX=$(python3 -c "print('{\"modifiers\":524288,\"keyCode\":49}'.encode().hex())")
defaults write com.luzivog.agentdictate hotkey.binding -data "$HEX"
defaults write com.luzivog.agentdictate hotkey.mode -string "pushToTalk"
defaults write com.luzivog.agentdictate onboarding.complete -bool true

echo "[QA] launching AgentDictate with mock OpenAI base URL…"
AGENTDICTATE_OPENAI_BASE_URL="http://127.0.0.1:18088/v1" \
AGENTDICTATE_OPENAI_API_KEY="sk-qa" \
"$APP/Contents/MacOS/AgentDictate" > "$LOG" 2>&1 &
sleep 3

check "app process alive"               "$(pgrep -f 'AgentDictate.app/Contents/MacOS' >/dev/null && echo true || echo false)"
check "tap installed (stderr)"          "$(stderr_contains 'hotkey tap installed')"
check "tap installed only ONCE"         "$( [ "$(grep -c 'hotkey tap installed' "$LOG")" = "1" ] && echo true || echo false )"

# ──────────────── focus target ────────────────

osascript -e 'tell application "TextEdit" to activate' > /dev/null 2>&1 || true
sleep 1
osascript <<'AS' > /dev/null 2>&1
tell application "TextEdit"
    if (count of documents) = 0 then make new document
    set text of front document to "QA: "
end tell
delay 0.3
tell application "System Events" to tell process "TextEdit" to set frontmost to true
AS
sleep 1

# ──────────────── push-to-talk happy path ────────────────

echo "[QA] push-to-talk: ⌥Space down → hold 1s → up"
cat > /tmp/qa-press.swift <<'SW'
import CoreGraphics
import Foundation
let src = CGEventSource(stateID: .hidSystemState)
let kc: CGKeyCode = 49
let down = CGEvent(keyboardEventSource: src, virtualKey: kc, keyDown: true)!
down.flags = .maskAlternate
down.post(tap: .cghidEventTap)
usleep(1_000_000)
let up = CGEvent(keyboardEventSource: src, virtualKey: kc, keyDown: false)!
up.flags = .maskAlternate
up.post(tap: .cghidEventTap)
SW
swift /tmp/qa-press.swift
echo "[QA] waiting up to 10s for clipboard…"
for i in $(seq 1 20); do
    if [ "$(pbpaste)" = "smoke test from mock openai" ]; then break; fi
    sleep 0.5
done

check "keyDown MATCH (push-to-talk)"    "$(stderr_contains 'hotkey MATCH type=10 keyCode=49')"
check "keyUp MATCH (push-to-talk)"      "$(stderr_contains 'hotkey MATCH type=11 keyCode=49')"
check "clipboard set after transcribe"  "$( [ "$(pbpaste)" = "smoke test from mock openai" ] && echo true || echo false )"
TE_CONTENT=$(osascript -e 'tell application "TextEdit" to get text of front document' 2>/dev/null || echo "")
check "text pasted into TextEdit"       "$( [[ "$TE_CONTENT" == *"smoke test from mock openai"* ]] && echo true || echo false )"

# ──────────────── modifier-released-first edge case ────────────────

echo "[QA] modifier-released-first: keyUp arrives WITHOUT modifier flag set"
osascript -e 'tell application "TextEdit" to set text of front document to "QA2: "' > /dev/null 2>&1 || true
sleep 0.5
cat > /tmp/qa-press-mod-first.swift <<'SW'
import CoreGraphics
import Foundation
let src = CGEventSource(stateID: .hidSystemState)
let kc: CGKeyCode = 49
let down = CGEvent(keyboardEventSource: src, virtualKey: kc, keyDown: true)!
down.flags = .maskAlternate
down.post(tap: .cghidEventTap)
usleep(800_000)
// Simulate user releasing modifier BEFORE the main key — keyUp arrives w/o flags.
let up = CGEvent(keyboardEventSource: src, virtualKey: kc, keyDown: false)!
up.flags = []
up.post(tap: .cghidEventTap)
SW
swift /tmp/qa-press-mod-first.swift
echo "[QA] waiting up to 10s for second transcript…"
for i in $(seq 1 20); do
    TE_CONTENT=$(osascript -e 'tell application "TextEdit" to get text of front document' 2>/dev/null || echo "")
    if [[ "$TE_CONTENT" == *"smoke test from mock openai"* ]]; then break; fi
    sleep 0.5
done

check "keyUp matches even w/o modifier" "$(grep -c 'hotkey MATCH type=11' "$LOG" | awk '{print ($1>=2)?"true":"false"}')"
TE_CONTENT=$(osascript -e 'tell application "TextEdit" to get text of front document' 2>/dev/null || echo "")
check "second transcript also pasted"   "$( [[ "$TE_CONTENT" == *"smoke test from mock openai"* ]] && echo true || echo false )"

# ──────────────── toggle mode ────────────────

echo "[QA] switching to toggle mode and pressing twice"
defaults write com.luzivog.agentdictate hotkey.mode -string "toggle"
sleep 0.5  # let observeSettings pick it up
osascript -e 'tell application "TextEdit" to set text of front document to "QA3: "' > /dev/null 2>&1 || true
sleep 0.5
# First press to START
cat > /tmp/qa-toggle.swift <<'SW'
import CoreGraphics
import Foundation
let src = CGEventSource(stateID: .hidSystemState)
let kc: CGKeyCode = 49
func tap() {
    let d = CGEvent(keyboardEventSource: src, virtualKey: kc, keyDown: true)!
    d.flags = .maskAlternate; d.post(tap: .cghidEventTap)
    usleep(40_000)
    let u = CGEvent(keyboardEventSource: src, virtualKey: kc, keyDown: false)!
    u.flags = .maskAlternate; u.post(tap: .cghidEventTap)
}
tap()
usleep(900_000)  // recording window
tap()
SW
swift /tmp/qa-toggle.swift
sleep 4

check "toggle: at least 4 hotkey events" "$(grep -c 'hotkey MATCH' "$LOG" | awk '{print ($1>=6)?"true":"false"}')"

# ──────────────── summary ────────────────

echo ""
echo "=========================================="
echo "  QA: $PASS passed, $FAIL failed"
echo "=========================================="
if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "Stderr log tail:"
    tail -40 "$LOG"
    exit 1
fi
