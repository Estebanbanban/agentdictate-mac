import AppKit
import AVFoundation
import ApplicationServices

enum PermissionStatus {
    case granted
    case denied
    case undetermined
}

@MainActor
final class PermissionsChecker: ObservableObject {
    @Published private(set) var microphone: PermissionStatus = .undetermined
    @Published private(set) var accessibility: PermissionStatus = .undetermined
    @Published private(set) var inputMonitoring: PermissionStatus = .undetermined

    func refresh() {
        microphone = currentMicrophone()
        accessibility = AXIsProcessTrusted() ? .granted : .denied
        inputMonitoring = currentInputMonitoring()
    }

    func requestMicrophone() async {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        microphone = granted ? .granted : .denied
    }

    func promptAccessibility() {
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        refresh()
    }

    func requestInputMonitoring() {
        if #available(macOS 10.15, *) {
            let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            inputMonitoring = granted ? .granted : .denied
            if !granted {
                openSystemSettings(.inputMonitoring)
            }
        }
    }

    func openSystemSettings(_ pane: SystemSettingsPane) {
        if let url = URL(string: pane.urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    private func currentMicrophone() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .undetermined
        @unknown default: return .undetermined
        }
    }

    private func currentInputMonitoring() -> PermissionStatus {
        if #available(macOS 10.15, *) {
            switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
            case kIOHIDAccessTypeGranted: return .granted
            case kIOHIDAccessTypeDenied: return .denied
            case kIOHIDAccessTypeUnknown: return .undetermined
            default: return .undetermined
            }
        }
        return .granted
    }
}

enum SystemSettingsPane {
    case microphone
    case accessibility
    case inputMonitoring

    var urlString: String {
        switch self {
        case .microphone:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .accessibility:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .inputMonitoring:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        }
    }
}
