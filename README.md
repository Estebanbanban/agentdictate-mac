# AgentDictate (macOS)

Native macOS port of [Luzivog/agentdictate](https://github.com/Luzivog/agentdictate). Menu bar app for push-to-talk dictation: hold a hotkey, speak, release — OpenAI transcribes, optional GPT cleanup, replacements, paste into the focused app.

**Theme:** Cortana / Halo HUD. Dark `#01040A` base, cyan `#22E4FF` HUD lines, animated hex grid, pulsing menu bar icon, RMS waveform during recording.

## Requirements

- macOS 13 Ventura or newer
- Xcode 15+ (for building)
- [xcodegen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- OpenAI API key

## Build & run

```sh
brew install xcodegen
xcodegen generate
open AgentDictate.xcodeproj
```

Press ⌘R in Xcode. The app launches as a menu bar item (no Dock icon). On first run an onboarding window walks through the three required permissions.

CLI build:

```sh
xcodebuild -project AgentDictate.xcodeproj -scheme AgentDictate -configuration Debug build
```

CLI tests:

```sh
xcodebuild -project AgentDictate.xcodeproj -scheme AgentDictate -destination 'platform=macOS' test
```

## Permissions

| Permission | Why |
|---|---|
| **Microphone** | Capture audio when the hotkey is held |
| **Accessibility** | Simulate ⌘V to paste into the focused app |
| **Input Monitoring** | Receive the global push-to-talk hotkey |

The app surfaces these in the onboarding screen with deep links to System Settings.

## Configuration

- **OpenAI API key** — Settings → OpenAI. Stored in the macOS Keychain (service `com.luzivog.agentdictate`). Never written to UserDefaults or plaintext on disk.
- **Hotkey** — default `⌥ + Space`. Push-to-talk and toggle modes.
- **Cleanup** — optional GPT pass after Whisper. Default model `gpt-4o-mini`. Custom system prompt.
- **Replacements** — plain or regex, case-sensitive flag, ordered. Stored at `~/Library/Application Support/AgentDictate/replacements.json`.

## Architecture

```
AgentDictate/
  App/                 SwiftUI entry, AppDelegate, hotkey + coordinator wiring
  Audio/               AVAudioEngine recorder, WAV encoder, RMS levels
  Hotkey/              CGEventTap-based global hotkey
  Keychain/            kSecClassGenericPassword wrapper
  OpenAI/              URLSession transcribe + cleanup, multipart, errors
  Permissions/         Mic / Accessibility / Input Monitoring status + prompts
  Pipeline/            DictationCoordinator state machine + Paster
  Replacements/        Rule model, engine, JSON store
  UI/MenuBar/          NSStatusItem controller with state machine
  UI/Onboarding/       Three-card permissions intro
  UI/Settings/         Settings window + Overview/Dictation/Replacements/OpenAI tabs
  UI/Theme/            CortanaTheme, HexGridView, PulsingRing, WaveformView, GlowModifier
```

## Differences from the Linux original

- **No `KeyboardShortcuts` SPM dependency** — `CGEventTap` directly. One less moving part, full control over push-to-talk and toggle behavior.
- **Default hotkey is ⌥Space**, not Ctrl+Space (which conflicts with the macOS input-source switcher).
- **No App Sandbox** — required for `CGEvent`-based paste.

## Status

v0.1 — unsigned dev build. Notarized DMG comes in v0.2.
