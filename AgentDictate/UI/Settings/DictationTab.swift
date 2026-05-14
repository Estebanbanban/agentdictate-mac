import SwiftUI

struct DictationTab: View {
    @EnvironmentObject var appSettings: AppSettingsStore
    @EnvironmentObject var hotkey: HotkeyManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CortanaHeader(title: "Dictation")
            CortanaPanel {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("HOTKEY")
                            .font(CortanaTheme.Font.display(11))
                            .tracking(2)
                            .foregroundStyle(CortanaTheme.Color.cyanSoft)
                            .frame(width: 100, alignment: .leading)
                        HotkeyRecorderView(binding: $appSettings.hotkeyBinding)
                    }
                    hotkeyStatusRow
                    Picker("Hotkey mode", selection: $appSettings.hotkeyMode) {
                        Text("Push-to-talk").tag(HotkeyMode.pushToTalk)
                        Text("Toggle").tag(HotkeyMode.toggle)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Toggle("Enable post-transcription cleanup", isOn: $appSettings.cleanupEnabled)
                    HStack {
                        Text("Cleanup model").foregroundStyle(CortanaTheme.Color.textDim)
                        Picker("", selection: $appSettings.cleanupModel) {
                            Text("gpt-4o-mini").tag("gpt-4o-mini")
                            Text("gpt-4o").tag("gpt-4o")
                            Text("gpt-4.1-mini").tag("gpt-4.1-mini")
                        }
                        .labelsHidden()
                        .disabled(!appSettings.cleanupEnabled)
                    }
                    TextField("Language code (e.g. en, fr, leave blank for auto)", text: $appSettings.language)
                        .textFieldStyle(.roundedBorder)
                    Toggle("Play sound on record start/stop", isOn: $appSettings.soundEnabled)
                    Toggle("Fade out music while recording (Spotify / Apple Music)", isOn: $appSettings.duckMusic)
                }
            }
            CortanaPanel {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CLEANUP PROMPT")
                        .font(CortanaTheme.Font.display(11))
                        .tracking(2)
                        .foregroundStyle(CortanaTheme.Color.cyanSoft)
                    TextEditor(text: $appSettings.cleanupPrompt)
                        .font(CortanaTheme.Font.mono(12))
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .background(CortanaTheme.Color.bgDeep.opacity(0.6))
                        .overlay(
                            Rectangle()
                                .stroke(CortanaTheme.Color.cyan.opacity(0.25), lineWidth: 1)
                        )
                }
            }
            Spacer()
        }
    }

    private var hotkeyStatusRow: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .cortanaGlow(color: statusColor, radius: 4, opacity: 0.8)
            Text(statusLabel)
                .font(CortanaTheme.Font.body(11))
                .foregroundStyle(CortanaTheme.Color.textDim)
            Spacer()
            Button("Refresh") { hotkey.refreshStatus() }
                .buttonStyle(.borderless)
            if hotkey.status == .permissionDenied {
                Button("Open Input Monitoring") {
                    if let url = URL(string: SystemSettingsPane.inputMonitoring.urlString) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderless)
            } else if hotkey.status != .active {
                Button("Reinstall") { hotkey.install() }
                    .buttonStyle(.borderless)
            }
        }
        .onAppear { hotkey.refreshStatus() }
        .onReceive(Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()) { _ in
            hotkey.refreshStatus()
        }
    }

    private var statusColor: Color {
        switch hotkey.status {
        case .active: return CortanaTheme.Color.cyan
        case .permissionDenied: return CortanaTheme.Color.danger
        case .uninstalled: return CortanaTheme.Color.textDim
        }
    }

    private var statusLabel: String {
        switch hotkey.status {
        case .active: return "Hotkey tap ACTIVE"
        case .permissionDenied: return "Hotkey tap BLOCKED — grant Input Monitoring then relaunch"
        case .uninstalled: return "Hotkey tap not installed"
        }
    }
}
