import SwiftUI

struct HexGridView: View {
    var hexSize: CGFloat = 22
    var lineWidth: CGFloat = 0.6
    var opacity: Double = 0.35

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                drawGrid(into: &ctx, size: size, time: t)
            }
            .blendMode(.plusLighter)
            .opacity(opacity)
        }
        .allowsHitTesting(false)
    }

    private func drawGrid(into ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let w = hexSize * sqrt(3)
        let h = hexSize * 1.5
        let cols = Int(size.width / w) + 2
        let rows = Int(size.height / h) + 2
        for row in -1...rows {
            for col in -1...cols {
                let x = CGFloat(col) * w + (row.isMultiple(of: 2) ? 0 : w / 2)
                let y = CGFloat(row) * h
                let phase = sin(time * 0.6 + Double(col) * 0.3 + Double(row) * 0.2)
                let alpha = 0.45 + 0.25 * phase
                let path = hexagonPath(at: CGPoint(x: x, y: y), size: hexSize)
                ctx.stroke(
                    path,
                    with: .color(CortanaTheme.Color.cyan.opacity(alpha)),
                    lineWidth: lineWidth
                )
            }
        }
    }

    private func hexagonPath(at center: CGPoint, size: CGFloat) -> Path {
        var p = Path()
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let pt = CGPoint(
                x: center.x + size * cos(angle),
                y: center.y + size * sin(angle)
            )
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
