import SwiftUI

struct DictationTab: View {
    @EnvironmentObject var appSettings: AppSettingsStore

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
}
