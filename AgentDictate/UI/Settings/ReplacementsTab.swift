import SwiftUI

struct ReplacementsTab: View {
    @EnvironmentObject var replacements: ReplacementsStore
    @State private var selection: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CortanaHeader(title: "Replacements")
            HStack(spacing: 10) {
                Button {
                    let new = ReplacementRule(pattern: "new", replacement: "")
                    replacements.upsert(new)
                    selection = new.id
                } label: {
                    Label("Add", systemImage: "plus")
                }
                Button(role: .destructive) {
                    if let id = selection { replacements.remove(id: id) }
                } label: {
                    Label("Remove", systemImage: "minus")
                }
                .disabled(selection == nil)
                Spacer()
            }
            CortanaPanel {
                VStack(spacing: 0) {
                    header
                    Divider().overlay(CortanaTheme.Color.cyan.opacity(0.2))
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach($replacements.rules) { $rule in
                                ruleRow(rule: $rule)
                                Divider().overlay(CortanaTheme.Color.cyan.opacity(0.08))
                            }
                            if replacements.rules.isEmpty {
                                Text("No rules yet. Press + to add one.")
                                    .font(CortanaTheme.Font.body(12))
                                    .foregroundStyle(CortanaTheme.Color.textDim)
                                    .padding(24)
                            }
                        }
                    }
                    .frame(minHeight: 240)
                }
            }
            Spacer()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            cell("PATTERN", flex: 1)
            cell("REPLACEMENT", flex: 1)
            cell("MODE", width: 80)
            cell("Aa", width: 36)
            cell("ON", width: 36)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .foregroundStyle(CortanaTheme.Color.cyanSoft)
        .font(CortanaTheme.Font.display(11))
    }

    private func ruleRow(rule: Binding<ReplacementRule>) -> some View {
        HStack(spacing: 8) {
            TextField("pattern", text: rule.pattern)
                .textFieldStyle(.plain)
                .font(CortanaTheme.Font.mono(12))
                .padding(6)
                .background(CortanaTheme.Color.bgDeep.opacity(0.5))
            TextField("replacement", text: rule.replacement)
                .textFieldStyle(.plain)
                .font(CortanaTheme.Font.mono(12))
                .padding(6)
                .background(CortanaTheme.Color.bgDeep.opacity(0.5))
            Picker("", selection: rule.mode) {
                Text("plain").tag(ReplacementRule.Mode.plain)
                Text("regex").tag(ReplacementRule.Mode.regex)
            }
            .labelsHidden()
            .frame(width: 80)
            Toggle("", isOn: rule.caseSensitive).labelsHidden().frame(width: 36)
            Toggle("", isOn: rule.enabled).labelsHidden().frame(width: 36)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { selection = rule.wrappedValue.id }
        .background(
            selection == rule.wrappedValue.id
                ? CortanaTheme.Color.cyan.opacity(0.08)
                : Color.clear
        )
    }

    private func cell(_ text: String, flex: CGFloat? = nil, width: CGFloat? = nil) -> some View {
        let view = Text(text).tracking(2)
        return Group {
            if let width {
                view.frame(width: width, alignment: .leading)
            } else if let flex {
                view.frame(maxWidth: .infinity * flex, alignment: .leading)
            } else {
                view
            }
        }
    }
}
