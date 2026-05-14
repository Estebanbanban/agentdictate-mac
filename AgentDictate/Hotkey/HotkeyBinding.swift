import Foundation
import Carbon.HIToolbox
import CoreGraphics

struct HotkeyBinding: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt64

    var flags: CGEventFlags { CGEventFlags(rawValue: modifiers) }

    static let `default` = HotkeyBinding(
        keyCode: UInt16(kVK_Space),
        modifiers: CGEventFlags.maskAlternate.rawValue
    )

    var displayString: String {
        var parts: [String] = []
        let f = CGEventFlags(rawValue: modifiers)
        if f.contains(.maskControl) { parts.append("⌃") }
        if f.contains(.maskAlternate) { parts.append("⌥") }
        if f.contains(.maskShift) { parts.append("⇧") }
        if f.contains(.maskCommand) { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    static func keyName(for keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Escape: return "Esc"
        case kVK_Delete: return "Delete"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default:
            if let ch = unicodeChar(for: keyCode) { return ch.uppercased() }
            return "Key \(keyCode)"
        }
    }

    private static func unicodeChar(for keyCode: UInt16) -> String? {
        let source = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        guard let layoutDataRaw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataRaw).takeUnretainedValue()
        let bytes = CFDataGetBytePtr(layoutData)
        let layout = UnsafeRawPointer(bytes!).assumingMemoryBound(to: UCKeyboardLayout.self)
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var realLength = 0
        let status = UCKeyTranslate(
            layout,
            keyCode,
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &realLength,
            &chars
        )
        guard status == noErr, realLength > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: realLength)
    }
}
