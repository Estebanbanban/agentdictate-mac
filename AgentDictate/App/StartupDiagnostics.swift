import AppKit
import ApplicationServices
import IOKit.hid

/// Startup-time diagnostics. Logs permission status and triggers eager
/// secret-store migration so any one-time prompts happen at launch rather
/// than the next time the user transcribes.
enum StartupDiagnostics {
    static func run() {
        logPermissions()
        migrateLegacySecretsIfNeeded()
    }

    private static func logPermissions() {
        let ax = AXIsProcessTrusted()
        let hid: String
        if #available(macOS 10.15, *) {
            switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
            case kIOHIDAccessTypeGranted: hid = "granted"
            case kIOHIDAccessTypeDenied: hid = "denied"
            case kIOHIDAccessTypeUnknown: hid = "unknown"
            default: hid = "other"
            }
        } else {
            hid = "n/a"
        }
        let bundleID = Bundle.main.bundleIdentifier ?? "?"
        let path = Bundle.main.bundlePath
        NSLog("AgentDictate: DIAG bundleID=\(bundleID) path=\(path)")
        NSLog("AgentDictate: DIAG Accessibility(AXIsProcessTrusted)=\(ax) InputMonitoring(IOHIDCheckAccess)=\(hid)")
    }

    private static func migrateLegacySecretsIfNeeded() {
        let store = KeychainStore()
        let key = (try? store.get(KeychainStore.openAIKeyAccount)) ?? nil
        if let k = key, !k.isEmpty {
            NSLog("AgentDictate: secret store has API key (len=\(k.count))")
        } else {
            NSLog("AgentDictate: secret store empty — user will need to enter API key in Settings → OpenAI")
        }
    }
}
