import AppKit
import Foundation

@MainActor
final class MusicController {

    struct Snapshot {
        let appBundleId: String
        let originalVolume: Int  // 0-100
        let wasPlaying: Bool
    }

    private var lastSnapshot: Snapshot?
    private let fadeDuration: TimeInterval = 0.4
    private let fadeSteps = 12

    private let supportedApps: [(name: String, bundleId: String)] = [
        ("Spotify", "com.spotify.client"),
        ("Music", "com.apple.Music"),
        ("Music", "com.apple.iTunes")  // legacy
    ]

    /// Fades out + pauses whichever supported player is currently playing.
    func fadeOutAndPause() async {
        guard let target = findActivePlayer() else { return }
        let original = getVolume(appName: target.name) ?? 70
        lastSnapshot = Snapshot(appBundleId: target.bundleId, originalVolume: original, wasPlaying: true)
        await rampVolume(appName: target.name, from: original, to: 0)
        runScript("tell application \"\(target.name)\" to pause")
    }

    /// Resumes + fades in to the snapshotted volume.
    func resumeAndFadeIn() async {
        guard let snap = lastSnapshot else { return }
        let appName = appNameForBundleId(snap.appBundleId)
        runScript("tell application \"\(appName)\" to play")
        await rampVolume(appName: appName, from: 0, to: snap.originalVolume)
        lastSnapshot = nil
    }

    private func findActivePlayer() -> (name: String, bundleId: String)? {
        for (name, bundleId) in supportedApps {
            guard isRunning(bundleId: bundleId) else { continue }
            if let state = playerState(appName: name), state == "playing" {
                return (name, bundleId)
            }
        }
        return nil
    }

    private func isRunning(bundleId: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }

    private func appNameForBundleId(_ id: String) -> String {
        supportedApps.first { $0.bundleId == id }?.name ?? "Music"
    }

    private func playerState(appName: String) -> String? {
        let script = "tell application \"\(appName)\" to return player state as string"
        return runScript(script)
    }

    private func getVolume(appName: String) -> Int? {
        let script = "tell application \"\(appName)\" to return sound volume"
        return runScript(script).flatMap { Int($0) }
    }

    private func setVolume(appName: String, value: Int) {
        let clamped = max(0, min(100, value))
        runScript("tell application \"\(appName)\" to set sound volume to \(clamped)")
    }

    private func rampVolume(appName: String, from: Int, to: Int) async {
        let stepDelay = UInt64(fadeDuration / Double(fadeSteps) * 1_000_000_000)
        for step in 1...fadeSteps {
            let progress = Double(step) / Double(fadeSteps)
            let value = Int(Double(from) + (Double(to) - Double(from)) * progress)
            setVolume(appName: appName, value: value)
            try? await Task.sleep(nanoseconds: stepDelay)
        }
        setVolume(appName: appName, value: to)
    }

    @discardableResult
    private func runScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return result.stringValue
    }
}
