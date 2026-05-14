import Foundation
import Combine

final class ReplacementsStore: ObservableObject {
    @Published var rules: [ReplacementRule]

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.luzivog.agentdictate.replacements", qos: .utility)
    private var cancellables = Set<AnyCancellable>()

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL()
        self.rules = Self.load(from: self.fileURL)
        $rules
            .dropFirst()
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] snapshot in self?.persist(snapshot) }
            .store(in: &cancellables)
    }

    func upsert(_ rule: ReplacementRule) {
        if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[idx] = rule
        } else {
            rules.append(rule)
        }
    }

    func remove(id: UUID) {
        rules.removeAll { $0.id == id }
    }

    func move(from source: IndexSet, to destination: Int) {
        rules.move(fromOffsets: source, toOffset: destination)
    }

    func replaceAll(_ newRules: [ReplacementRule]) {
        rules = newRules
    }

    private func persist(_ snapshot: [ReplacementRule]) {
        let url = fileURL
        queue.async {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let data = try JSONEncoder.pretty.encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                NSLog("ReplacementsStore persist failed: \(error)")
            }
        }
    }

    private static func load(from url: URL) -> [ReplacementRule] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([ReplacementRule].self, from: data)) ?? []
    }

    static func defaultURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return support
            .appendingPathComponent("AgentDictate", isDirectory: true)
            .appendingPathComponent("replacements.json")
    }
}

private extension JSONEncoder {
    static let pretty: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}
