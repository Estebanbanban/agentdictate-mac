import SwiftUI

enum CortanaTheme {

    enum Color {
        static let bgDeep    = SwiftUI.Color(hex: 0x01040A)
        static let bgPanel   = SwiftUI.Color(hex: 0x06121E)
        static let cyan      = SwiftUI.Color(hex: 0x22E4FF)
        static let cyanSoft  = SwiftUI.Color(hex: 0x69F0FF)
        static let blue      = SwiftUI.Color(hex: 0x1B6FFF)
        static let violet    = SwiftUI.Color(hex: 0x7A5BFF)
        static let grid      = SwiftUI.Color(hex: 0x0C2238)
        static let text      = SwiftUI.Color(hex: 0xD8F4FF)
        static let textDim   = SwiftUI.Color(hex: 0x6E97AE)
        static let danger    = SwiftUI.Color(hex: 0xFF4D6D)
    }

    enum Font {
        static func display(_ size: CGFloat, weight: SwiftUI.Font.Weight = .bold) -> SwiftUI.Font {
            // Orbitron is bundled in step 12 final pass; fall back to rounded SF until then.
            .system(size: size, weight: weight, design: .rounded)
        }
        static func body(_ size: CGFloat = 13, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default)
        }
        static func mono(_ size: CGFloat = 12) -> SwiftUI.Font {
            .system(size: size, weight: .regular, design: .monospaced)
        }
    }

    enum Metrics {
        static let cornerRadius: CGFloat = 2
        static let borderWidth: CGFloat = 1
        static let panelPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 18
        static let tracking: CGFloat = 4
    }

    enum Motion {
        static let pulseDuration: Double = 1.6
        static let hoverDuration: Double = 0.12
        static let tabSwitchDuration: Double = 0.08
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
