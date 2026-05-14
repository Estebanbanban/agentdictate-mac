import SwiftUI

struct RecordingHUDView: View {
    @ObservedObject var viewModel: RecordingHUDViewModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(CortanaTheme.Color.bgPanel.opacity(0.85))
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(CortanaTheme.Color.bgDeep.opacity(0.85))
                )
            RoundedRectangle(cornerRadius: 4)
                .stroke(CortanaTheme.Color.cyan.opacity(0.55), lineWidth: 1)
                .cortanaGlow(radius: 8, opacity: 0.45)
            HStack(spacing: 12) {
                statusIndicator
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
        }
        .frame(width: 360, height: 84)
        .padding(8)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch viewModel.state {
        case .recording:
            ZStack {
                PulsingRing(color: CortanaTheme.Color.cyan, lineWidth: 1.2, duration: 1.0)
                    .frame(width: 28, height: 28)
                Circle()
                    .fill(CortanaTheme.Color.cyan)
                    .frame(width: 8, height: 8)
                    .cortanaGlow()
            }
        case .processing:
            RotatingArcs().frame(width: 28, height: 28).cortanaGlow()
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(CortanaTheme.Color.danger)
                .font(.system(size: 18))
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            label
            switch viewModel.state {
            case .recording:
                WaveformView(levels: viewModel.levels)
                    .frame(height: 28)
                    .cortanaGlow(radius: 4, opacity: 0.5)
            case .processing:
                progressBar
            case .error:
                Text(viewModel.errorMessage ?? "Error")
                    .font(CortanaTheme.Font.body(11))
                    .foregroundStyle(CortanaTheme.Color.danger)
                    .lineLimit(2)
            case .idle:
                EmptyView()
            }
        }
    }

    private var label: some View {
        Text(labelText)
            .font(CortanaTheme.Font.display(11))
            .tracking(3)
            .foregroundStyle(CortanaTheme.Color.cyanSoft)
    }

    private var labelText: String {
        switch viewModel.state {
        case .recording: return "RECORDING"
        case .processing: return "TRANSCRIBING"
        case .error: return "ERROR"
        case .idle: return ""
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(CortanaTheme.Color.cyan.opacity(0.15))
                    .frame(height: 2)
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    let phase = (sin(t * 2.4) + 1) / 2
                    Rectangle()
                        .fill(CortanaTheme.Color.cyan)
                        .frame(width: geo.size.width * 0.3, height: 2)
                        .offset(x: (geo.size.width * 0.7) * CGFloat(phase))
                        .cortanaGlow()
                }
            }
        }
        .frame(height: 28)
    }
}
