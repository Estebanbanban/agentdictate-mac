import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)
    case dataDecodingFailed
    case ioFailed(String)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status): return "Keychain error \(status)"
        case .dataDecodingFailed: return "Stored value could not be decoded as UTF-8"
        case .ioFailed(let m): return "Secret store I/O failed: \(m)"
        }
    }
}

/// File-backed secret store. We do NOT use Keychain on ad-hoc-signed builds
/// because the signature changes between rebuilds, which invalidates the ACL
/// and forces the user to re-authenticate on every launch.
///
/// Storage: `~/Library/Application Support/AgentDictate/secrets.json`, mode 0600.
/// On first read for an account, if the file is missing the entry, we attempt a
/// one-time migration from the legacy keychain via `/usr/bin/security` so the
/// user does not have to re-enter their key.
struct KeychainStore {
    let service: String

    init(service: String = "com.luzivog.agentdictate") {
        self.service = service
    }

    func set(_ value: String, for account: String) throws {
        var dict = try readAll()
        dict[account] = value
        try writeAll(dict)
    }

    func get(_ account: String) throws -> String? {
        let dict = try readAll()
        if let v = dict[account] { return v }
        // One-time migration from the legacy keychain entry.
        if let migrated = legacyKeychainRead(account: account) {
            var fresh = dict
            fresh[account] = migrated
            try? writeAll(fresh)
            return migrated
        }
        return nil
    }

    func delete(_ account: String) throws {
        var dict = try readAll()
        dict.removeValue(forKey: account)
        try writeAll(dict)
    }

    // MARK: - Storage

    private var storeURL: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("AgentDictate", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        return dir.appendingPathComponent("secrets.json")
    }

    private func readAll() throws -> [String: String] {
        let url = storeURL
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data: Data
        do { data = try Data(contentsOf: url) } catch { throw KeychainError.ioFailed(error.localizedDescription) }
        if data.isEmpty { return [:] }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }
        return obj
    }

    private func writeAll(_ dict: [String: String]) throws {
        let url = storeURL
        let data: Data
        do { data = try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]) }
        catch { throw KeychainError.ioFailed(error.localizedDescription) }
        // Write atomically, then chmod 0600 so other users on the machine can't read it.
        do {
            try data.write(to: url, options: [.atomic])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            throw KeychainError.ioFailed(error.localizedDescription)
        }
    }

    /// Reads the legacy keychain entry via `security` CLI. Used once during
    /// migration so existing users keep their saved key without re-entry.
    /// Silent on failure — migration is best-effort.
    private func legacyKeychainRead(account: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = ["find-generic-password", "-s", service, "-a", account, "-w"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do { try task.run(); task.waitUntilExit() } catch { return nil }
        guard task.terminationStatus == 0 else { return nil }
        let raw = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension KeychainStore {
    static let openAIKeyAccount = "openai_api_key"
}
