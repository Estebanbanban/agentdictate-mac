import Foundation

struct ReplacementRule: Identifiable, Codable, Hashable {
    enum Mode: String, Codable, CaseIterable {
        case plain
        case regex
    }

    let id: UUID
    var pattern: String
    var replacement: String
    var mode: Mode
    var caseSensitive: Bool
    var enabled: Bool

    init(
        id: UUID = UUID(),
        pattern: String,
        replacement: String,
        mode: Mode = .plain,
        caseSensitive: Bool = false,
        enabled: Bool = true
    ) {
        self.id = id
        self.pattern = pattern
        self.replacement = replacement
        self.mode = mode
        self.caseSensitive = caseSensitive
        self.enabled = enabled
    }
}
