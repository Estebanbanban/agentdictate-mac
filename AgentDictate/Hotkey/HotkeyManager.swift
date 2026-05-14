import AppKit
import Carbon.HIToolbox
import Combine

enum HotkeyMode: String, CaseIterable, Codable {
    case pushToTalk
    case toggle
}

@MainActor
final class HotkeyManager: ObservableObject {
    @Published var mode: HotkeyMode = .pushToTalk

    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var keyDown = false

    private(set) var keyCode: CGKeyCode = CGKeyCode(kVK_Space)
    private(set) var modifierFlags: CGEventFlags = .maskAlternate

    func install() {
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
        ) else { return }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
    }

    func uninstall() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    func setBinding(keyCode: CGKeyCode, flags: CGEventFlags) {
        self.keyCode = keyCode
        self.modifierFlags = flags
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let code = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
        let matches = code == keyCode && flags.contains(modifierFlags)
        guard matches else { return Unmanaged.passUnretained(event) }

        switch type {
        case .keyDown where !keyDown:
            keyDown = true
            switch mode {
            case .pushToTalk: onPress()
            case .toggle: onPress()
            }
            return nil
        case .keyUp where keyDown:
            keyDown = false
            if mode == .pushToTalk { onRelease() }
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private static let cgCallback: CGEventTapCallBack = { _, type, event, info in
        guard let info else { return Unmanaged.passUnretained(event) }
        let manager = Unmanaged<HotkeyManager>.fromOpaque(info).takeUnretainedValue()
        let result = DispatchQueue.main.sync { manager.handle(type: type, event: event) }
        return result
    }
}
