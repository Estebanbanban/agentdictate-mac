import Foundation

enum ReplacementsEngine {
    static func apply(_ input: String, rules: [ReplacementRule]) -> String {
        rules.reduce(input) { partial, rule in
            guard rule.enabled else { return partial }
            switch rule.mode {
            case .plain:
                return applyPlain(partial, rule: rule)
            case .regex:
                return applyRegex(partial, rule: rule)
            }
        }
    }

    private static func applyPlain(_ input: String, rule: ReplacementRule) -> String {
        guard !rule.pattern.isEmpty else { return input }
        let options: String.CompareOptions = rule.caseSensitive ? [] : [.caseInsensitive]
        return input.replacingOccurrences(of: rule.pattern, with: rule.replacement, options: options)
    }

    private static func applyRegex(_ input: String, rule: ReplacementRule) -> String {
        var regexOptions: NSRegularExpression.Options = []
        if !rule.caseSensitive { regexOptions.insert(.caseInsensitive) }
        guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: regexOptions) else {
            return input
        }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.stringByReplacingMatches(
            in: input,
            options: [],
            range: range,
            withTemplate: rule.replacement
        )
    }
}
