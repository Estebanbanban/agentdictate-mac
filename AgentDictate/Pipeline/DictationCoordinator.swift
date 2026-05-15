import Foundation
import SwiftUI

@MainActor
protocol AudioRecording: AnyObject {
    func start() throws
    func stop() -> Data
}

extension AudioRecorder: AudioRecording {}

protocol TextPasting {
    func copyAndPaste(_ text: String)
}

struct PasteboardPaster: TextPasting {
    func copyAndPaste(_ text: String) { Paster.copyAndPaste(text) }
}

@MainActor
final class DictationCoordinator: ObservableObject {

    enum State: Equatable {
        case idle
        case recording
        case processing
        case error(String)
    }

    @Published private(set) var state: State = .idle

    let recorder: AudioRecording
    let replacements: ReplacementsStore
    let client: OpenAIClient
    let paster: TextPasting
    let musicController: MusicController?
    var settings: DictationSettings

    init(
        recorder: AudioRecording? = nil,
        replacements: ReplacementsStore,
        client: OpenAIClient = OpenAIClient(),
        paster: TextPasting = PasteboardPaster(),
        musicController: MusicController? = nil,
        settings: DictationSettings = DictationSettings(),
        attachDefaultMusicController: Bool = true
    ) {
        self.recorder = recorder ?? AudioRecorder()
        self.replacements = replacements
        self.client = client
        self.paster = paster
        if let provided = musicController {
            self.musicController = provided
        } else if attachDefaultMusicController {
            self.musicController = MusicController()
        } else {
            self.musicController = nil
        }
        self.settings = settings
    }

    func startRecording() {
        NSLog("AgentDictate: coordinator.startRecording() called (state=\(state))")
        guard state == .idle else { return }
        do {
            try recorder.start()
            state = .recording
            NSLog("AgentDictate: recorder.start() ok, state -> recording")
            if settings.duckMusicWhileRecording {
                Task { await musicController?.fadeOutAndPause() }
            }
        } catch {
            NSLog("AgentDictate: recorder.start() FAILED: \(error.localizedDescription)")
            state = .error(error.localizedDescription)
        }
    }

    func finishRecording() {
        NSLog("AgentDictate: coordinator.finishRecording() called (state=\(state))")
        guard state == .recording else { return }
        let wav = recorder.stop()
        state = .processing
        Task { await transcribeAndPaste(wav: wav) }
    }

    /// Aborts the current recording without sending to OpenAI. Used by the Escape key.
    func cancelRecording() {
        if state == .recording {
            _ = recorder.stop()
        }
        state = .idle
        if settings.duckMusicWhileRecording {
            Task { await musicController?.resumeAndFadeIn() }
        }
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
                self.paster.copyAndPaste(final)
                self.state = .idle
            }
            if settings.duckMusicWhileRecording {
                await musicController?.resumeAndFadeIn()
            }
        } catch {
            await MainActor.run { self.state = .error(error.localizedDescription) }
            if settings.duckMusicWhileRecording {
                await musicController?.resumeAndFadeIn()
            }
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
    var duckMusicWhileRecording: Bool = true
}
