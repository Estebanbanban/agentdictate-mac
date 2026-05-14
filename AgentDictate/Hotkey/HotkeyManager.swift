import AppKit
import Carbon.HIToolbox
import Combine

enum HotkeyMode: String, CaseIterable, Codable {
    case pushToTalk
    case toggle
}

@MainActor
final class HotkeyManager: ObservableObject {
    enum Status: String { case uninstalled, active, permissionDenied }

    @Published var mode: HotkeyMode = .pushToTalk
    @Published private(set) var status: Status = .uninstalled

    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}
    /// Optional callback fired when Escape is pressed during a recording.
    var onCancel: () -> Void = {}

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var keyDown = false

    private(set) var keyCode: CGKeyCode = CGKeyCode(kVK_Space)
    private(set) var modifierFlags: CGEventFlags = .maskAlternate

    var keyCodeRaw: CGKeyCode {
        get { keyCode }
        set { keyCode = newValue }
    }
    var modifierFlagsRaw: CGEventFlags {
        get { modifierFlags }
        set { modifierFlags = newValue }
    }

    @discardableResult
    func install() -> Bool {
        uninstall()
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let info = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: HotkeyManager.cgCallback,
            userInfo: info
        ) else {
            status = .permissionDenied
            NSLog("AgentDictate: CGEvent.tapCreate failed — Input Monitoring likely not granted")
            return false
        }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        status = .active
        NSLog("AgentDictate: hotkey tap installed (keyCode=\(keyCode), flags=\(modifierFlags.rawValue))")
        return true
    }

    func uninstall() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        status = .uninstalled
    }

    func setBinding(keyCode: CGKeyCode, flags: CGEventFlags) {
        let changed = self.keyCode != keyCode || self.modifierFlags != flags
        self.keyCode = keyCode
        self.modifierFlags = flags
        // Only reinstall if we have no tap yet — once active, the existing tap
        // reads keyCode/modifierFlags fresh on every event so no reinstall needed.
        if status != .active {
            install()
        } else if changed {
            // Binding changed but tap is already running — nothing to do, the
            // callback reads the new values directly off the manager.
        }
    }


    private static let cgCallback: CGEventTapCallBack = { _, type, event, info in
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            NSLog("AgentDictate: tap disabled (\(type.rawValue)) — re-enabling")
            if let info {
                let manager = Unmanaged<HotkeyManager>.fromOpaque(info).takeUnretainedValue()
                DispatchQueue.main.async { _ = manager.install() }
            }
            return Unmanaged.passUnretained(event)
        }
        guard let info else { return Unmanaged.passUnretained(event) }
        let manager = Unmanaged<HotkeyManager>.fromOpaque(info).takeUnretainedValue()
        let code = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
        // Escape (keyCode 53) with no modifiers cancels an in-flight recording.
        if code == 53 && flags.isEmpty && type == .keyDown {
            DispatchQueue.main.async { manager.onCancel() }
            return Unmanaged.passUnretained(event)  // don't consume — let Esc still reach the focused app
        }
        let mgrKeyCode = manager.keyCode
        let mgrFlags = manager.modifierFlags
        guard !mgrFlags.isEmpty else { return Unmanaged.passUnretained(event) }

        // keyDown must match keyCode AND modifiers (so we don't fire on a stray
        // unmodified press of the same physical key).
        // keyUp matches on keyCode ALONE, because in real keyboard timing the
        // user often releases the modifier (Shift/Option/etc) before the main
        // key, and the keyUp event for the main key arrives with empty flags.
        // Requiring flags on keyUp left users with recordings that never stopped.
        let codeMatches = (code == mgrKeyCode)
        let modsMatch = flags.contains(mgrFlags)
        let matches: Bool
        switch type {
        case .keyDown: matches = codeMatches && modsMatch
        case .keyUp:   matches = codeMatches  // permissive — see comment above
        default:       matches = false
        }
        if matches {
            NSLog("AgentDictate: hotkey MATCH type=\(type.rawValue) keyCode=\(code) flags=\(flags.rawValue)")
        }
        guard matches else { return Unmanaged.passUnretained(event) }

        DispatchQueue.main.async { manager.fire(type: type) }
        return nil
    }

    fileprivate func fire(type: CGEventType) {
        switch type {
        case .keyDown where !keyDown:
            keyDown = true
            switch mode {
            case .pushToTalk: onPress()
            case .toggle: onPress()
            }
        case .keyUp where keyDown:
            keyDown = false
            if mode == .pushToTalk { onRelease() }
        default:
            break
        }
    }
}
