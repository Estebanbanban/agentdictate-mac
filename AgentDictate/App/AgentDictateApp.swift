import SwiftUI
import Carbon.HIToolbox
import IOKit.hid

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
        applyActivationPolicy()
        CortanaFonts.registerAll()
        // Eagerly register with TCC so AgentDictate appears in System Settings
        // → Privacy & Security → Input Monitoring even before the user opens
        // onboarding. macOS only lists apps that have actually requested the
        // permission; just installing a CGEventTap doesn't add them.
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        StartupDiagnostics.run()
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
        } else {
            // Open Settings immediately on launch so the user has visible feedback
            // that the app started. They can close it; the app stays in menu bar / Dock.
            showSettings()
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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // No visible windows — user clicked Dock icon or Cmd-tabbed to us with no UI up.
            // Show whichever window makes sense for current state.
            if !appSettings.onboardingComplete {
                showOnboarding()
            } else {
                showSettings()
            }
        }
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // If the user activates us (Dock click, Cmd+Tab) with no visible windows, open Settings.
        let hasWindow = NSApp.windows.contains { $0.isVisible && !$0.title.isEmpty }
        if !hasWindow {
            if appSettings.onboardingComplete {
                showSettings()
            } else if onboardingWindow == nil {
                showOnboarding()
            }
        }
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
        hotkey.keyCodeRaw = CGKeyCode(b.keyCode)
        hotkey.modifierFlagsRaw = b.flags
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
            guard let self else { return }
            // Only push-to-talk uses keyUp to stop. In toggle mode, the next
            // keyDown handles stop; firing finishRecording() on every release
            // collapses toggle into push-to-talk.
            guard self.appSettings.hotkeyMode == .pushToTalk else { return }
            self.coordinator.finishRecording()
        }
        hotkey.onCancel = { [weak self] in
            self?.coordinator.cancelRecording()
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
                // Don't reinstall the tap — just update binding fields in place.
                self.hotkey.keyCodeRaw = CGKeyCode(b.keyCode)
                self.hotkey.modifierFlagsRaw = b.flags
                self.coordinator.settings = self.appSettings.dictationSettings()
                self.applyActivationPolicy()
            }
        }
    }

    private func applyActivationPolicy() {
        let policy: NSApplication.ActivationPolicy = appSettings.showInDock ? .regular : .accessory
        if NSApp.activationPolicy() != policy {
            NSApp.setActivationPolicy(policy)
        }
    }
}
