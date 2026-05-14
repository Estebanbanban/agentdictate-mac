import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appSettings: AppSettingsStore
    @EnvironmentObject var replacements: ReplacementsStore
    @State private var selection: Tab = .overview

    enum Tab: String, CaseIterable, Identifiable {
        case overview, dictation, replacements, openai
        var id: String { rawValue }
        var title: String {
            switch self {
            case .overview: return "Overview"
            case .dictation: return "Dictation"
            case .replacements: return "Replacements"
            case .openai: return "OpenAI"
            }
        }
    }

    var body: some View {
        CortanaSurface {
            HStack(spacing: 0) {
                sidebar
                Divider().overlay(CortanaTheme.Color.cyan.opacity(0.2))
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 760, minHeight: 520)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AGENTDICTATE")
                .font(CortanaTheme.Font.display(13))
                .tracking(4)
                .foregroundStyle(CortanaTheme.Color.cyanSoft)
                .padding(.bottom, 14)
            ForEach(Tab.allCases) { tab in
                SidebarTabRow(tab: tab, selection: $selection)
            }
            Spacer()
        }
        .padding(20)
        .frame(width: 200)
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch selection {
            case .overview: OverviewTab()
            case .dictation: DictationTab()
            case .replacements: ReplacementsTab()
            case .openai: OpenAITab()
            }
        }
        .padding(28)
    }
}

private struct SidebarTabRow: View {
    let tab: SettingsView.Tab
    @Binding var selection: SettingsView.Tab

    var body: some View {
        let isSelected = selection == tab
        Button {
            withAnimation(.easeOut(duration: CortanaTheme.Motion.tabSwitchDuration)) {
                selection = tab
            }
        } label: {
            HStack(spacing: 8) {
                Text(isSelected ? "[" : " ")
                    .foregroundStyle(CortanaTheme.Color.cyan.opacity(0.7))
                Text(tab.title.uppercased())
                    .font(CortanaTheme.Font.display(12))
                    .tracking(3)
                Spacer()
                Text(isSelected ? "]" : " ")
                    .foregroundStyle(CortanaTheme.Color.cyan.opacity(0.7))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .foregroundStyle(isSelected ? CortanaTheme.Color.cyanSoft : CortanaTheme.Color.text)
            .background(isSelected ? CortanaTheme.Color.cyan.opacity(0.08) : Color.clear)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? CortanaTheme.Color.cyan.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityIdentifier("tab.\(tab.rawValue)")
    }
}
