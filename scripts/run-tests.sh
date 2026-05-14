#!/usr/bin/env bash
# Plain-Swift test runner — used when full Xcode isn't installed and XCTest
# is unavailable. Compiles production source + the test script into a single
# executable, runs it, reports pass/fail.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SOURCES=(
    AgentDictate/Replacements/ReplacementRule.swift
    AgentDictate/Replacements/ReplacementsEngine.swift
    AgentDictate/Replacements/ReplacementsStore.swift
    AgentDictate/Hotkey/HotkeyBinding.swift
    AgentDictate/Audio/WAVEncoder.swift
    AgentDictate/Audio/AudioRecorder.swift
    AgentDictate/OpenAI/OpenAIError.swift
    AgentDictate/OpenAI/MultipartBuilder.swift
    AgentDictate/OpenAI/OpenAIClient.swift
    AgentDictate/Keychain/KeychainStore.swift
    AgentDictate/Pipeline/Paster.swift
    AgentDictate/Pipeline/DictationCoordinator.swift
)

OUT="$ROOT/.build/test-runner"
mkdir -p "$ROOT/.build"

SDK=$(xcrun --sdk macosx --show-sdk-path)
swiftc \
    -sdk "$SDK" \
    -target arm64-apple-macos13.0 \
    -framework Carbon \
    -parse-as-library \
    -o "$OUT" \
    "${SOURCES[@]}" \
    tests-no-xcode/main.swift

"$OUT"
