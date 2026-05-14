import SwiftUI

struct WaveformView: View {
    var levels: [Float]
    var color: Color = CortanaTheme.Color.cyan
    var barWidth: CGFloat = 3
    var spacing: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let count = max(Int(geo.size.width / (barWidth + spacing)), 1)
            let trimmed = Array(levels.suffix(count))
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<count, id: \.self) { i in
                    let level = i < trimmed.count ? CGFloat(trimmed[i]) : 0
                    Capsule()
                        .fill(color.opacity(0.85))
                        .frame(width: barWidth, height: max(2, level * geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

struct GlowModifier: ViewModifier {
    var color: Color = CortanaTheme.Color.cyan
    var radius: CGFloat = 6
    var opacity: Double = 0.6

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(opacity), radius: radius)
            .shadow(color: color.opacity(opacity * 0.4), radius: radius * 2)
    }
}

extension View {
    func cortanaGlow(
        color: Color = CortanaTheme.Color.cyan,
        radius: CGFloat = 6,
        opacity: Double = 0.6
    ) -> some View {
        modifier(GlowModifier(color: color, radius: radius, opacity: opacity))
    }
}
