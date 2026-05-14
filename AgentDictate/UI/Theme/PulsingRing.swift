import SwiftUI

struct PulsingRing: View {
    var color: Color = CortanaTheme.Color.cyan
    var lineWidth: CGFloat = 1.5
    var duration: Double = CortanaTheme.Motion.pulseDuration

    @State private var phase: Double = 0

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration)
            let progress = t / duration
            ZStack {
                Circle()
                    .stroke(color.opacity(1 - progress), lineWidth: lineWidth)
                    .scaleEffect(0.6 + progress * 0.6)
                Circle()
                    .stroke(color.opacity(0.6), lineWidth: lineWidth)
                    .scaleEffect(0.7 + sin(progress * .pi) * 0.15)
            }
        }
    }
}

struct RotatingArcs: View {
    var color: Color = CortanaTheme.Color.cyan
    var lineWidth: CGFloat = 2

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let angle = Angle.degrees(t.truncatingRemainder(dividingBy: 2) * 180)
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.18)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(angle)
                Circle()
                    .trim(from: 0.55, to: 0.72)
                    .stroke(color.opacity(0.6), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(angle * -1.3)
            }
        }
    }
}
