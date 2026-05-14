import SwiftUI
import AppKit

struct HotkeyRecorderView: View {
    @Binding var binding: HotkeyBinding
    @State private var recording = false
    @State private var monitor: Any?
    @State private var warning: String?

    var body: some View {
        HStack(spacing: 10) {
            Button {
                if recording { stopRecording() } else { startRecording() }
            } label: {
                Text(recording ? "Press a key…" : binding.displayString)
                    .font(CortanaTheme.Font.mono(13))
                    .frame(minWidth: 140)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(
                        recording
                            ? CortanaTheme.Color.cyan.opacity(0.15)
                            : CortanaTheme.Color.bgDeep.opacity(0.6)
                    )
                    .overlay(
                        Rectangle().stroke(
                            recording ? CortanaTheme.Color.cyanSoft : CortanaTheme.Color.cyan.opacity(0.35),
                            lineWidth: 1
                        )
                    )
                    .foregroundStyle(CortanaTheme.Color.cyanSoft)
            }
            .buttonStyle(.plain)

            if recording {
                Button("Cancel") { stopRecording() }
                    .buttonStyle(.borderless)
            } else {
                Button("Reset") { binding = .default; warning = nil }
                    .buttonStyle(.borderless)
            }
            if let warning {
                Text(warning)
                    .font(CortanaTheme.Font.body(11))
                    .foregroundStyle(CortanaTheme.Color.danger)
            }
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            handle(event: event)
            return nil
        }
    }

    private func stopRecording() {
        recording = false
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    private func handle(event: NSEvent) {
        let modifiers = event.modifierFlags
        var flags: CGEventFlags = []
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if flags.isEmpty {
            warning = "Add at least one modifier (⌃ ⌥ ⌘ ⇧)"
            return
        }
        warning = nil
        binding = HotkeyBinding(keyCode: UInt16(event.keyCode), modifiers: flags.rawValue)
        stopRecording()
    }
}
