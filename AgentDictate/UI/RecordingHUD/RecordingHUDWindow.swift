import AppKit
import SwiftUI
import Combine

@MainActor
final class RecordingHUDWindow {
    private let window: NSWindow
    private let viewModel = RecordingHUDViewModel()
    private var cancellables = Set<AnyCancellable>()
    private let coordinator: DictationCoordinator
    private let recorder: AudioRecorder

    init(coordinator: DictationCoordinator, recorder: AudioRecorder) {
        self.coordinator = coordinator
        self.recorder = recorder
        let hosting = NSHostingView(rootView: RecordingHUDView(viewModel: viewModel))
        let size = NSSize(width: 360, height: 84)
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        positionAtBottom()
        observe()
    }

    private func positionAtBottom() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = window.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.minY + 40
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func observe() {
        coordinator.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.apply(state) }
            .store(in: &cancellables)
        recorder.$levels
            .receive(on: RunLoop.main)
            .sink { [weak self] levels in self?.viewModel.levels = levels }
            .store(in: &cancellables)
    }

    private func apply(_ state: DictationCoordinator.State) {
        viewModel.state = state
        switch state {
        case .recording, .processing:
            show()
        case .idle:
            hideAfterDelay()
        case .error(let msg):
            viewModel.errorMessage = msg
            show()
            hideAfterDelay(seconds: 4)
        }
    }

    private func show() {
        positionAtBottom()
        window.orderFrontRegardless()
    }

    private func hideAfterDelay(seconds: Double = 0.6) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self else { return }
            switch self.viewModel.state {
            case .idle, .error:
                self.window.orderOut(nil)
            default:
                break
            }
        }
    }
}

@MainActor
final class RecordingHUDViewModel: ObservableObject {
    @Published var state: DictationCoordinator.State = .idle
    @Published var levels: [Float] = []
    @Published var errorMessage: String?
}
