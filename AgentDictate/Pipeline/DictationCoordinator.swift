import Foundation
import SwiftUI

@MainActor
final class DictationCoordinator: ObservableObject {

    enum State: Equatable {
        case idle
        case recording
        case processing
        case error(String)
    }

    @Published private(set) var state: State = .idle

    let recorder: AudioRecorder
    let replacements: ReplacementsStore
    let client: OpenAIClient
    var settings: DictationSettings

    init(
        recorder: AudioRecorder? = nil,
        replacements: ReplacementsStore,
        client: OpenAIClient = OpenAIClient(),
        settings: DictationSettings = DictationSettings()
    ) {
        self.recorder = recorder ?? AudioRecorder()
        self.replacements = replacements
        self.client = client
        self.settings = settings
    }

    func startRecording() {
        guard state == .idle else { return }
        do {
            try recorder.start()
            state = .recording
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func finishRecording() {
        guard state == .recording else { return }
        let wav = recorder.stop()
        state = .processing
        Task { await transcribeAndPaste(wav: wav) }
    }

    private func transcribeAndPaste(wav: Data) async {
        do {
            let raw = try await client.transcribe(wav: wav, language: settings.language)
            let cleaned = settings.cleanupEnabled
                ? try await client.clean(
                    text: raw,
                    systemPrompt: settings.cleanupPrompt,
                    model: settings.cleanupModel
                )
                : raw
            let final = ReplacementsEngine.apply(cleaned, rules: replacements.rules)
            await MainActor.run {
                Paster.copyAndPaste(final)
                self.state = .idle
            }
        } catch {
            await MainActor.run { self.state = .error(error.localizedDescription) }
        }
    }
}

struct DictationSettings {
    var cleanupEnabled: Bool = false
    var cleanupModel: String = "gpt-4o-mini"
    var cleanupPrompt: String = """
    You are a transcription editor. Lightly clean the user's dictation: remove filler words \
    (um, uh, like), fix obvious typos, keep the user's meaning and tone, do not summarize, \
    do not add information. Return only the cleaned text.
    """
    var language: String? = nil
}
