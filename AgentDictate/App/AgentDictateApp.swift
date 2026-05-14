import SwiftUI
import Carbon.HIToolbox

@main
struct AgentDictateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appSettings = AppSettingsStore()
    let replacements = ReplacementsStore()
    lazy var coordinator: DictationCoordinator = {
        DictationCoordinator(
            replacements: replacements,
            settings: appSettings.dictationSettings()
        )
    }()
    lazy var hotkey: HotkeyManager = HotkeyManager()
    private var statusItem: StatusItemController?
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var recordingHUD: RecordingHUDWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = StatusItemController(coordinator: coordinator) { [weak self] in
            self?.showSettings()
        }
        if let audioRecorder = coordinator.recorder as? AudioRecorder {
            recordingHUD = RecordingHUDWindow(coordinator: coordinator, recorder: audioRecorder)
        }
        configureHotkey()
        observeSettings()
        if !appSettings.onboardingComplete {
            showOnboarding()
        }
    }

    func showSettings() {
        if let window = settingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let view = SettingsView()
            .environmentObject(appSettings)
            .environmentObject(replacements)
            .environmentObject(hotkey)
        let host = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: host)
        window.title = "AgentDictate Settings"
        window.setContentSize(NSSize(width: 820, height: 560))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
    }

    func completeOnboarding() {
        appSettings.onboardingComplete = true
        onboardingWindow?.close()
        onboardingWindow = nil
    }

    private func showOnboarding() {
        let host = NSHostingController(rootView: PermissionsOnboarding { [weak self] in
            self?.completeOnboarding()
        })
        let window = NSWindow(contentViewController: host)
        window.title = "AgentDictate"
        window.setContentSize(NSSize(width: 600, height: 540))
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        onboardingWindow = window
    }

    private func configureHotkey() {
        hotkey.mode = appSettings.hotkeyMode
        let b = appSettings.hotkeyBinding
        hotkey.setBinding(keyCode: CGKeyCode(b.keyCode), flags: b.flags)
        hotkey.onPress = { [weak self] in
            guard let self else { return }
            switch self.appSettings.hotkeyMode {
            case .pushToTalk:
                self.coordinator.startRecording()
            case .toggle:
                if self.coordinator.state == .recording {
                    self.coordinator.finishRecording()
                } else {
                    self.coordinator.startRecording()
                }
            }
        }
        hotkey.onRelease = { [weak self] in
            self?.coordinator.finishRecording()
        }
        hotkey.install()
    }

    private func observeSettings() {
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.hotkey.mode = self.appSettings.hotkeyMode
                let b = self.appSettings.hotkeyBinding
                self.hotkey.setBinding(keyCode: CGKeyCode(b.keyCode), flags: b.flags)
                self.coordinator.settings = self.appSettings.dictationSettings()
            }
        }
    }
}
