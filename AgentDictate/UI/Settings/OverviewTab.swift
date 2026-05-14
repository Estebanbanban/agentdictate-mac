import SwiftUI

struct OverviewTab: View {
    @EnvironmentObject var appSettings: AppSettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CortanaHeader(title: "Overview")
            CortanaPanel {
                VStack(alignment: .leading, spacing: 10) {
                    statRow("Hotkey", value: appSettings.hotkeyBinding.displayString)
                    statRow("Mode", value: appSettings.hotkeyMode == .pushToTalk ? "Push-to-talk" : "Toggle")
                    statRow("Cleanup", value: appSettings.cleanupEnabled ? appSettings.cleanupModel : "off")
                    statRow("Language", value: appSettings.language.isEmpty ? "auto" : appSettings.language)
                }
            }
            CortanaPanel {
                VStack(alignment: .leading, spacing: 8) {
                    Text("HOW TO USE")
                        .font(CortanaTheme.Font.display(12))
                        .tracking(3)
                        .foregroundStyle(CortanaTheme.Color.cyanSoft)
                    bullet("Hold the hotkey to record. Release to transcribe.")
                    bullet("In Toggle mode, tap the hotkey to start, tap again to stop.")
                    bullet("Replacements run after Whisper (and after cleanup, if enabled).")
                    bullet("Text is pasted into the currently-focused app via ⌘V.")
                }
            }
            Spacer()
        }
    }

    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(CortanaTheme.Font.display(11))
                .tracking(2)
                .foregroundStyle(CortanaTheme.Color.textDim)
            Spacer()
            Text(value)
                .font(CortanaTheme.Font.mono(12))
                .foregroundStyle(CortanaTheme.Color.cyanSoft)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("›").foregroundStyle(CortanaTheme.Color.cyan.opacity(0.7))
            Text(text)
                .font(CortanaTheme.Font.body(12))
                .foregroundStyle(CortanaTheme.Color.text)
        }
    }
}
