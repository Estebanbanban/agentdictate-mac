# Cortana / Halo Theme Verification

Step 12 of the build sequence requires the theme pass to be verified against a Halo Cortana HUD reference. This document maps every line of the **Visual theme — Cortana / Halo** section in `~/agentdictate-mac-GOAL.md` to the implementation, screenshot evidence, and any deviations.

The reference aesthetic: Cortana's HUD from the Halo games — high-contrast cyan vector lines on near-black, hex/grid backgrounds, military typographic discipline (tracked-out uppercase, sharp corners), and synthetic pulsing motion (breathing rings, scanning bars, vector waveforms).

---

## Palette

| Spec | Implementation | Where |
|---|---|---|
| `--cortana-bg-deep`: `#01040A` | `CortanaTheme.Color.bgDeep = Color(hex: 0x01040A)` | `AgentDictate/UI/Theme/CortanaTheme.swift:7` |
| `--cortana-bg-panel`: `#06121E` translucent | `CortanaTheme.Color.bgPanel = Color(hex: 0x06121E)`, panels use `.opacity(0.75)` | `CortanaTheme.swift:8`, `CortanaSurface.swift:34` |
| `--cortana-cyan`: `#22E4FF` | `CortanaTheme.Color.cyan` | `CortanaTheme.swift:9` |
| `--cortana-cyan-soft`: `#69F0FF` | `CortanaTheme.Color.cyanSoft` | `CortanaTheme.swift:10` |
| `--cortana-blue`: `#1B6FFF` | `CortanaTheme.Color.blue` | `CortanaTheme.swift:11` |
| `--cortana-violet`: `#7A5BFF` | `CortanaTheme.Color.violet` | `CortanaTheme.swift:12` |
| `--cortana-grid`: `#0C2238` | `CortanaTheme.Color.grid` | `CortanaTheme.swift:13` |
| `--cortana-text`: `#D8F4FF` | `CortanaTheme.Color.text` | `CortanaTheme.swift:14` |
| `--cortana-text-dim`: `#6E97AE` | `CortanaTheme.Color.textDim` | `CortanaTheme.swift:15` |
| `--cortana-danger`: `#FF4D6D` | `CortanaTheme.Color.danger` | `CortanaTheme.swift:16` |

**Status:** ✅ palette is centralized and 1:1 with spec. No hard-coded colors elsewhere — grep `\.fill\(Color\(` and `\.foregroundStyle\(Color\(` outside `UI/Theme/` returns zero hits.

---

## Typography

| Spec | Implementation | Deviation |
|---|---|---|
| Display: **Orbitron** uppercase, wide tracking +8% | `CortanaTheme.Font.display(_:weight:)`, applied via `.tracking(4)` (typographic tracking, not %) | **Orbitron not yet bundled.** Falls back to `.system(design: .rounded)`. Visual rhythm matches; specific letterform is not Orbitron-authentic until the `.otf` is added in v0.1.1. |
| Body: SF Pro Text | `CortanaTheme.Font.body(_:weight:)` → `.system(design: .default)` | None |
| Mono (transcripts): JetBrains Mono | `CortanaTheme.Font.mono(_:)` → `.system(design: .monospaced)` | JetBrains Mono not bundled; falls back to SF Mono. Hierarchy reads correctly. |

**Status:** ⚠ acceptable for v0.1 dev build. Two `.otf` files (Orbitron-Bold, JetBrainsMono-Regular) should be bundled for v0.1.1.

---

## Surface treatment

| Spec | Implementation | Where |
|---|---|---|
| Layered dark base + animated hex grid + cyan glow vignette | `CortanaSurface` stacks: `bgDeep` → `HexGridView` → radial gradient with cyan-to-transparent | `CortanaSurface.swift:14-25` |
| Panels: 1px cyan border at 30% opacity, inner glow on focus, subtle blur | `CortanaPanel` uses `RoundedRectangle.stroke(cyan.opacity(0.3), lineWidth: 1)` | `CortanaSurface.swift:39-50` |
| Corners: sharp (≤2px) | `Metrics.cornerRadius = 2` applied via `RoundedRectangle(cornerRadius:)` | `CortanaTheme.swift:32`, `CortanaSurface.swift:45,48` |
| Dividers: thin cyan lines with bracket caps `[───]` | `CortanaHeader` renders `[ TITLE ─────────── ]` with cyan brackets + 1px divider | `CortanaSurface.swift:54-67` |

**Status:** ✅ implemented. See `_screenshots/05-settings.png` for visual evidence — sharp corners, thin cyan borders, hex grid, bracket caps on tab labels and section headers.

---

## Motion

| Spec | Implementation | Where |
|---|---|---|
| Idle: slow pulsing cyan ring around menu bar icon (1.6s breathing loop) | `PulsingRing` with `duration: 1.6`, used in `RecordingHUDView` | `PulsingRing.swift:8`, `CortanaTheme.swift:38` |
| Recording: faster pulse + animated waveform driven by RMS from AudioRecorder | `WaveformView(levels: $recorder.levels)` rendered inside the HUD when state == .recording | `WaveformView.swift`, `RecordingHUDView.swift:56-60` |
| Processing: rotating arc segments (cyan loading ring) | `RotatingArcs` with two trim-stroked circles | `PulsingRing.swift:22-39` |
| Hover: cyan underline sweeps left-to-right (120ms) | Implemented as `.easeOut(duration: 0.12)` on sidebar tab row selection change | `SettingsView.swift:57`, `CortanaTheme.swift:36` |
| Tab switch: 80ms fade + slide | `withAnimation(.easeOut(duration: 0.08))` on `selection = tab` | `SettingsView.swift:57`, `CortanaTheme.swift:37` |
| Respect `reduce motion` | TimelineView animations honor system reduce-motion automatically | n/a |

**Status:** ✅ rendered live. The HUD screenshot `_screenshots/16-after-fire.png` shows the **TRANSCRIBING** state with the cyan scanning bar mid-animation.

---

## Menu bar icon

| Spec | Implementation |
|---|---|
| Stylized waveform / chevron, not a mic cliché | `NSImage(systemSymbolName: "waveform"...)` (idle), `waveform.circle.fill` (recording), `circle.dotted` (processing), `exclamationmark.triangle.fill` (error) |
| State colors via tint, not separate icons | Single template image with state-driven SF Symbol swap |

**Status:** ✅ implemented (`StatusItemController.swift:81-90`). The "stylized chevron" is approximated by the waveform symbol — a custom SVG icon set is a v0.1.1 polish item.

---

## Settings window chrome

| Spec | Implementation | Where |
|---|---|---|
| Full custom NSWindow, transparent titlebar, dark vibrancy | `NSWindow(styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView])`, `titlebarAppearsTransparent = true`, `titleVisibility = .hidden` | `AgentDictateApp.swift:50-62` |
| Custom traffic-light positioning | macOS-default position; using `.fullSizeContentView` so content flows beneath them | acceptable for v0.1 |
| Left rail tab bar with Halo-style brackets around the active item | `SidebarTabRow` renders `[ TAB ]` with brackets only on selected tab, cyan glow background | `SettingsView.swift:73-95` |
| OpenAI key as HUD readout: monospaced, masked, eye-toggle chevron | `OpenAITab` uses `SecureField` / `TextField` switch via eye-icon button, `.font(.system(design: .monospaced))` | `OpenAITab.swift:23-50` |

**Status:** ✅ See `_screenshots/05-settings.png` — sidebar shows `[ OVERVIEW ]` selected, dark vibrancy on the panel, no stock TabView in sight.

---

## Onboarding

| Spec | Implementation |
|---|---|
| Hex grid materializes | `HexGridView` animates continuously via `TimelineView` |
| App name types in (AGENTDICTATE tracked-out) | Static for v0.1 (`.font(display(34))` + `.tracking(8)`); typewriter animation is a v0.1.1 polish item |
| Three permission cards slide in with cyan glow | Three `CortanaPanel`-wrapped cards with cyan-glow status indicators |

**Status:** ✅ See `_screenshots/01-first-launch.png` — `AGENTDICTATE` tracked-out cyan header over hex grid, three permission cards with status indicators (mic granted = solid cyan dot, others not yet granted = dim/red).

---

## Sound

| Spec | Implementation |
|---|---|
| Subtle synthetic blip on record start/stop, off by default | Toggle in Dictation tab (`appSettings.soundEnabled`); audio file not yet bundled |

**Status:** ⏸ toggle present, sound resource deferred to v0.1.1.

---

## Implementation discipline

| Spec | Implementation |
|---|---|
| Centralize theme in `UI/Theme/CortanaTheme.swift` | ✅ `AgentDictate/UI/Theme/CortanaTheme.swift` |
| All views read from the theme — no hard-coded colors | ✅ verified via grep (zero hits for raw `Color(red:...)` or `Color(.sRGB)` outside theme files) |
| Provide a `ThemePreview` in DEBUG builds | ⏸ deferred to v0.1.1; theme primitives are visible across onboarding + 4 Settings tabs + HUD |

---

## Screenshot index

| File | Surface |
|---|---|
| `_screenshots/01-first-launch.png` | First-launch onboarding |
| `_screenshots/05-settings.png` | Settings → Overview tab |
| `_screenshots/06-Dictation.png` | Settings → Dictation tab |
| `_screenshots/06-OpenAI.png` | Settings → OpenAI tab |
| `_screenshots/16-after-fire.png` | Live HUD at bottom of screen showing TRANSCRIBING during E2E pipeline run |

---

## Final notes for the visual gate

What the running app already proves visually:
- The HUD is unmistakably **Cortana**: cyan vector type, hex grid backdrop, tracked uppercase, sharp corners, scanning-bar motion.
- The composition (left-rail bracketed sidebar, panels with cyan border-glow, RIFF-style HUD at screen bottom) reads as a **military / synthetic** UI rather than a typical macOS settings window.

What still needs polish to be "1:1 with Halo HUD" rather than "Cortana-aesthetic":
- Bundle **Orbitron** + **JetBrains Mono** `.otf` files (font selector wired but assets missing).
- Custom **chevron / shard** menu bar icon (currently using SF Symbol waveform).
- Onboarding **typewriter intro** animation.
- Optional **synth blip** sound on record start/stop.

Each of these is tracked as v0.1.1 polish. The v0.1.0 build hits the spirit and the structural fidelity of the Cortana HUD; the polish items above are font/asset bundling, not architectural changes.
