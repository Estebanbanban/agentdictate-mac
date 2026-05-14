import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let item: NSStatusItem
    private var cancellables = Set<AnyCancellable>()
    private let coordinator: DictationCoordinator
    private let openSettingsHandler: () -> Void

    init(coordinator: DictationCoordinator, openSettings: @escaping () -> Void) {
        self.coordinator = coordinator
        self.openSettingsHandler = openSettings
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureButton()
        installMenu()
        observeState()
    }

    @objc func openSettings() {
        openSettingsHandler()
    }

    private func configureButton() {
        guard let button = item.button else { return }
        button.image = makeImage(for: .idle)
        button.image?.isTemplate = false
        button.toolTip = "AgentDictate — idle"
    }

    private func installMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "AgentDictate", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit AgentDictate",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        item.menu = menu
    }

    private func observeState() {
        coordinator.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.apply(state) }
            .store(in: &cancellables)
    }

    private func apply(_ state: DictationCoordinator.State) {
        guard let button = item.button else { return }
        button.image = makeImage(for: state)
        switch state {
        case .idle:
            button.toolTip = "AgentDictate — idle"
        case .recording:
            button.toolTip = "AgentDictate — recording"
        case .processing:
            button.toolTip = "AgentDictate — processing"
        case .error(let msg):
            button.toolTip = "AgentDictate — error: \(msg)"
            showErrorNotification(msg)
        }
    }

    private func makeImage(for state: DictationCoordinator.State) -> NSImage? {
        let symbol: String
        switch state {
        case .idle: symbol = "waveform"
        case .recording: symbol = "waveform.circle.fill"
        case .processing: symbol = "circle.dotted"
        case .error: symbol = "exclamationmark.triangle.fill"
        }
        let img = NSImage(systemSymbolName: symbol, accessibilityDescription: "AgentDictate")
        img?.isTemplate = false
        return img
    }

    private func showErrorNotification(_ message: String) {
        let notification = NSUserNotification()
        notification.title = "AgentDictate error"
        notification.informativeText = message
        NSUserNotificationCenter.default.deliver(notification)
    }
}
