import Foundation
import Combine

@MainActor
final class AppSettingsStore: ObservableObject {

    @Published var hotkeyMode: HotkeyMode {
        didSet { defaults.set(hotkeyMode.rawValue, forKey: Keys.hotkeyMode) }
    }
    @Published var cleanupEnabled: Bool {
        didSet { defaults.set(cleanupEnabled, forKey: Keys.cleanupEnabled) }
    }
    @Published var cleanupModel: String {
        didSet { defaults.set(cleanupModel, forKey: Keys.cleanupModel) }
    }
    @Published var cleanupPrompt: String {
        didSet { defaults.set(cleanupPrompt, forKey: Keys.cleanupPrompt) }
    }
    @Published var language: String {
        didSet { defaults.set(language, forKey: Keys.language) }
    }
    @Published var onboardingComplete: Bool {
        didSet { defaults.set(onboardingComplete, forKey: Keys.onboardingComplete) }
    }
    @Published var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Keys.soundEnabled) }
    }
    @Published var hotkeyBinding: HotkeyBinding {
        didSet { persistHotkey() }
    }
    @Published var duckMusic: Bool {
        didSet { defaults.set(duckMusic, forKey: Keys.duckMusic) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let rawMode = defaults.string(forKey: Keys.hotkeyMode) ?? HotkeyMode.pushToTalk.rawValue
        self.hotkeyMode = HotkeyMode(rawValue: rawMode) ?? .pushToTalk
        self.cleanupEnabled = defaults.bool(forKey: Keys.cleanupEnabled)
        self.cleanupModel = defaults.string(forKey: Keys.cleanupModel) ?? "gpt-4o-mini"
        self.cleanupPrompt = defaults.string(forKey: Keys.cleanupPrompt) ?? DictationSettings().cleanupPrompt
        self.language = defaults.string(forKey: Keys.language) ?? ""
        self.onboardingComplete = defaults.bool(forKey: Keys.onboardingComplete)
        self.soundEnabled = defaults.bool(forKey: Keys.soundEnabled)
        if let data = defaults.data(forKey: Keys.hotkeyBinding),
           let decoded = try? JSONDecoder().decode(HotkeyBinding.self, from: data) {
            self.hotkeyBinding = decoded
        } else {
            self.hotkeyBinding = .default
        }
        self.duckMusic = defaults.object(forKey: Keys.duckMusic) as? Bool ?? true
    }

    private func persistHotkey() {
        if let data = try? JSONEncoder().encode(hotkeyBinding) {
            defaults.set(data, forKey: Keys.hotkeyBinding)
        }
    }

    func dictationSettings() -> DictationSettings {
        DictationSettings(
            cleanupEnabled: cleanupEnabled,
            cleanupModel: cleanupModel,
            cleanupPrompt: cleanupPrompt,
            language: language.isEmpty ? nil : language,
            duckMusicWhileRecording: duckMusic
        )
    }

    private enum Keys {
        static let hotkeyMode = "hotkey.mode"
        static let hotkeyBinding = "hotkey.binding"
        static let cleanupEnabled = "cleanup.enabled"
        static let cleanupModel = "cleanup.model"
        static let cleanupPrompt = "cleanup.prompt"
        static let language = "transcribe.language"
        static let onboardingComplete = "onboarding.complete"
        static let soundEnabled = "sound.enabled"
        static let duckMusic = "music.duck"
    }
}
