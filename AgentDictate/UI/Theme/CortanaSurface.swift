import SwiftUI

struct CortanaSurface<Content: View>: View {
    let content: () -> Content
    var showGrid: Bool = true

    init(showGrid: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.showGrid = showGrid
        self.content = content
    }

    var body: some View {
        ZStack {
            CortanaTheme.Color.bgDeep.ignoresSafeArea()
            if showGrid { HexGridView().ignoresSafeArea() }
            RadialGradient(
                colors: [
                    CortanaTheme.Color.blue.opacity(0.18),
                    CortanaTheme.Color.bgDeep.opacity(0)
                ],
                center: .topLeading,
                startRadius: 40,
                endRadius: 520
            )
            .blendMode(.plusLighter)
            .ignoresSafeArea()
            content()
        }
        .preferredColorScheme(.dark)
        .foregroundStyle(CortanaTheme.Color.text)
    }
}

struct CortanaPanel<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(CortanaTheme.Metrics.panelPadding)
            .background(
                RoundedRectangle(cornerRadius: CortanaTheme.Metrics.cornerRadius)
                    .fill(CortanaTheme.Color.bgPanel.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CortanaTheme.Metrics.cornerRadius)
                    .stroke(CortanaTheme.Color.cyan.opacity(0.3), lineWidth: CortanaTheme.Metrics.borderWidth)
            )
    }
}

struct CortanaHeader: View {
    let title: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("[").foregroundStyle(CortanaTheme.Color.cyan.opacity(0.6))
            Text(title.uppercased())
                .font(CortanaTheme.Font.display(18))
                .tracking(CortanaTheme.Metrics.tracking)
                .foregroundStyle(CortanaTheme.Color.cyanSoft)
            Rectangle()
                .fill(CortanaTheme.Color.cyan.opacity(0.4))
                .frame(height: 1)
            Text("]").foregroundStyle(CortanaTheme.Color.cyan.opacity(0.6))
        }
    }
}
