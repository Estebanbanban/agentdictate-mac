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

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var keyDown = false

    private(set) var keyCode: CGKeyCode = CGKeyCode(kVK_Space)
    private(set) var modifierFlags: CGEventFlags = .maskAlternate

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
        self.keyCode = keyCode
        self.modifierFlags = flags
        if status != .active {
            install()
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
        let mgrKeyCode = manager.keyCode
        let mgrFlags = manager.modifierFlags
        let matches = code == mgrKeyCode && flags.contains(mgrFlags) && !mgrFlags.isEmpty
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
