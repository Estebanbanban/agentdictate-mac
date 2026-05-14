import SwiftUI

struct PermissionsOnboarding: View {
    @StateObject private var checker = PermissionsChecker()
    var onComplete: () -> Void

    var body: some View {
        CortanaSurface {
            VStack(alignment: .leading, spacing: 22) {
                Text("AGENTDICTATE")
                    .font(CortanaTheme.Font.display(34))
                    .tracking(8)
                    .foregroundStyle(CortanaTheme.Color.cyanSoft)
                    .cortanaGlow()
                Text("Grant the three permissions below to enable system-wide dictation.")
                    .font(CortanaTheme.Font.body(14))
                    .foregroundStyle(CortanaTheme.Color.textDim)

                permissionCard(
                    title: "Microphone",
                    detail: "Capture audio when the hotkey is held.",
                    status: checker.microphone,
                    action: { Task { await checker.requestMicrophone() } },
                    fallback: { checker.openSystemSettings(.microphone) }
                )
                permissionCard(
                    title: "Accessibility",
                    detail: "Required to paste transcribed text into the focused app.",
                    status: checker.accessibility,
                    action: { checker.promptAccessibility() },
                    fallback: { checker.openSystemSettings(.accessibility) }
                )
                permissionCard(
                    title: "Input Monitoring",
                    detail: "Required for the global push-to-talk hotkey. After granting, quit and relaunch AgentDictate — macOS only applies new TCC grants on restart.",
                    status: checker.inputMonitoring,
                    action: { checker.requestInputMonitoring() },
                    fallback: { checker.openSystemSettings(.inputMonitoring) }
                )

                HStack {
                    Button("Refresh") { checker.refresh() }
                    Spacer()
                    Button("Continue") { onComplete() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!allGranted)
                }
            }
            .padding(36)
        }
        .frame(minWidth: 560, minHeight: 520)
        .onAppear { checker.refresh() }
    }

    private var allGranted: Bool {
        checker.microphone == .granted &&
        checker.accessibility == .granted &&
        checker.inputMonitoring == .granted
    }

    @ViewBuilder
    private func permissionCard(
        title: String,
        detail: String,
        status: PermissionStatus,
        action: @escaping () -> Void,
        fallback: @escaping () -> Void
    ) -> some View {
        CortanaPanel {
            HStack(alignment: .top, spacing: 16) {
                statusIndicator(status)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title.uppercased())
                        .font(CortanaTheme.Font.display(13))
                        .tracking(3)
                        .foregroundStyle(CortanaTheme.Color.text)
                    Text(detail)
                        .font(CortanaTheme.Font.body(12))
                        .foregroundStyle(CortanaTheme.Color.textDim)
                }
                Spacer()
                Button(status == .granted ? "Granted" : (status == .denied ? "Open Settings" : "Request")) {
                    status == .denied ? fallback() : action()
                }
                .disabled(status == .granted)
            }
        }
    }

    private func statusIndicator(_ status: PermissionStatus) -> some View {
        Circle()
            .fill(color(for: status))
            .frame(width: 10, height: 10)
            .cortanaGlow(color: color(for: status), radius: 4, opacity: 0.8)
    }

    private func color(for status: PermissionStatus) -> Color {
        switch status {
        case .granted: return CortanaTheme.Color.cyan
        case .denied: return CortanaTheme.Color.danger
        case .undetermined: return CortanaTheme.Color.textDim
        }
    }
}
