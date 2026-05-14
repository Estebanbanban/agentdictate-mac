// Plain-Swift test runner — no XCTest. Mirrors the XCTest suite so we can
// run unit tests without full Xcode installed (XCTest ships with Xcode).
import Foundation
import CoreGraphics

private final class TestStats {
    var passed = 0
    var failed = 0
}

private let stats = TestStats()
private let start = Date()

private func check(_ name: String, _ condition: @autoclosure () -> Bool, _ msg: String = "") {
    if condition() {
        stats.passed += 1
        print("  ✓ \(name)")
    } else {
        stats.failed += 1
        print("  ✗ \(name) \(msg)")
    }
}

private func group(_ name: String) {
    print("\n\(name)")
}

// ──────────────── shared mocks ────────────────

private final class StubTransport: HTTPTransport, @unchecked Sendable {
    var nextData: Data = Data()
    var nextStatus: Int = 200
    var lastRequest: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!, statusCode: nextStatus, httpVersion: nil, headerFields: nil
        )!
        return (nextData, response)
    }
}

@MainActor
private final class MockRecorder: AudioRecording {
    var started = false
    var stopReturn: Data = Data("RIFFmock".utf8)
    func start() throws { started = true }
    func stop() -> Data { stopReturn }
}

@MainActor
private final class MockPaster: TextPasting {
    var pasted: String?
    func copyAndPaste(_ text: String) { pasted = text }
}

// ──────────────── synchronous tests ────────────────

private func runSync() {
    group("ReplacementsEngine")
    let r1 = ReplacementRule(pattern: "claude", replacement: "Cortana")
    check("plain case insensitive",
          ReplacementsEngine.apply("Ask Claude please", rules: [r1]) == "Ask Cortana please")
    let r2 = ReplacementRule(pattern: "Claude", replacement: "Cortana", caseSensitive: true)
    check("plain case sensitive skips mismatch",
          ReplacementsEngine.apply("ask claude please", rules: [r2]) == "ask claude please")
    let ordered = [
        ReplacementRule(pattern: "TODO", replacement: "DONE"),
        ReplacementRule(pattern: "DONE", replacement: "SHIPPED")
    ]
    check("rules are ordered",
          ReplacementsEngine.apply("TODO list", rules: ordered) == "SHIPPED list")
    let disabled = ReplacementRule(pattern: "x", replacement: "y", enabled: false)
    check("disabled rule skipped",
          ReplacementsEngine.apply("xxx", rules: [disabled]) == "xxx")
    let regex = ReplacementRule(
        pattern: #"(\d+)\s*dollars"#,
        replacement: #"\$$1"#,
        mode: .regex
    )
    check("regex captures + template",
          ReplacementsEngine.apply("It costs 50 dollars and 20 dollars", rules: [regex])
            == "It costs $50 and $20")
    let bad = ReplacementRule(pattern: "(unterminated", replacement: "x", mode: .regex)
    check("invalid regex leaves input",
          ReplacementsEngine.apply("hello", rules: [bad]) == "hello")
    let empty = ReplacementRule(pattern: "", replacement: "x")
    check("empty pattern is noop",
          ReplacementsEngine.apply("hello", rules: [empty]) == "hello")

    group("HotkeyBinding")
    let def = HotkeyBinding.default
    check("default is option+space",
          def.displayString.contains("⌥") && def.displayString.contains("Space"))
    let cmdShift = HotkeyBinding(
        keyCode: 0x09,
        modifiers: CGEventFlags.maskCommand.union(.maskShift).rawValue
    )
    check("display order ⇧⌘",
          cmdShift.displayString.contains("⇧") && cmdShift.displayString.contains("⌘"))
    let encoded = try? JSONEncoder().encode(def)
    let decoded = encoded.flatMap { try? JSONDecoder().decode(HotkeyBinding.self, from: $0) }
    check("codable roundtrip", decoded == def)

    group("WAVEncoder")
    let samples: [Int16] = [0, 100, -100, 32000, -32000]
    let data = WAVEncoder.encode(samples: samples, sampleRate: 16000)
    check("starts with RIFF", data.prefix(4) == Data("RIFF".utf8))
    check("WAVE tag at offset 8", data.subdata(in: 8..<12) == Data("WAVE".utf8))
    check("total size matches", data.count == 44 + samples.count * 2)

    group("MultipartBuilder")
    var mp = MultipartBuilder(boundary: "TEST123")
    mp.appendField(name: "model", value: "whisper-1")
    mp.appendFile(name: "file", filename: "x.wav", mimeType: "audio/wav", data: Data([0x52, 0x49]))
    let body = mp.finalize()
    let s = String(data: body, encoding: .utf8) ?? ""
    check("contains boundary", s.contains("--TEST123"))
    check("contains field", s.contains("name=\"model\""))
    check("contains filename", s.contains("filename=\"x.wav\""))
    check("ends with terminator", s.hasSuffix("--TEST123--\r\n"))
}

// ──────────────── async OpenAIClient tests ────────────────

private func runOpenAITests() async {
    group("OpenAIClient")
    do {
        let stub = StubTransport()
        stub.nextData = #"{"text":"hello world"}"#.data(using: .utf8)!
        let client = OpenAIClient(transport: stub, apiKeyProvider: { "sk-test" })
        let text = try await client.transcribe(wav: Data([0x52, 0x49, 0x46, 0x46]))
        check("transcribe returns text", text == "hello world")
        check("Authorization header set",
              stub.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
        check("multipart Content-Type",
              (stub.lastRequest?.value(forHTTPHeaderField: "Content-Type") ?? "").hasPrefix("multipart/form-data"))
    } catch {
        check("transcribe returns text", false, "threw: \(error)")
    }

    group("OpenAIClient missing key")
    do {
        let client = OpenAIClient(transport: StubTransport(), apiKeyProvider: { nil })
        _ = try await client.transcribe(wav: Data())
        check("throws missingAPIKey", false)
    } catch OpenAIError.missingAPIKey {
        check("throws missingAPIKey", true)
    } catch {
        check("throws missingAPIKey", false, "got: \(error)")
    }

    group("OpenAIClient http error")
    do {
        let stub = StubTransport()
        stub.nextStatus = 401
        stub.nextData = #"{"error":"unauthorized"}"#.data(using: .utf8)!
        let client = OpenAIClient(transport: stub, apiKeyProvider: { "sk-test" })
        _ = try await client.transcribe(wav: Data())
        check("expected throw", false)
    } catch let OpenAIError.http(status, body) {
        check("401 surfaces", status == 401)
        check("body included", body.contains("unauthorized"))
    } catch {
        check("expected http error", false, "got: \(error)")
    }
}

// ──────────────── async DictationCoordinator E2E ────────────────

@MainActor
private func runCoordinatorE2E() async {
    group("DictationCoordinator E2E (mocked transport + recorder + paster)")
    let stub = StubTransport()
    stub.nextData = #"{"text":"hello cortana"}"#.data(using: .utf8)!
    let client = OpenAIClient(transport: stub, apiKeyProvider: { "sk-test" })
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("rep-\(UUID()).json")
    let store = ReplacementsStore(fileURL: tmp)
    store.upsert(ReplacementRule(pattern: "cortana", replacement: "Cortana"))
    let recorder = MockRecorder()
    let paster = MockPaster()
    let coord = DictationCoordinator(
        recorder: recorder,
        replacements: store,
        client: client,
        paster: paster,
        musicController: nil,
        settings: DictationSettings(),
        attachDefaultMusicController: false
    )

    check("initial state is idle", coord.state == .idle)
    coord.startRecording()
    check("startRecording sets state to recording", coord.state == .recording)
    check("recorder was started", recorder.started)
    coord.finishRecording()
    check("finishRecording sets state to processing", coord.state == .processing)

    var waited = 0
    while waited < 100 && coord.state != .idle {
        try? await Task.sleep(nanoseconds: 50_000_000)
        waited += 1
    }
    check("state returns to idle after transcribe", coord.state == .idle,
          "stuck in \(coord.state) after \(waited * 50)ms")
    check(
        "replacement rule applied (cortana → Cortana)",
        paster.pasted == "hello Cortana",
        "got: \(paster.pasted ?? "nil")"
    )
    check(
        "OpenAI got the WAV in multipart body",
        (stub.lastRequest?.value(forHTTPHeaderField: "Content-Type") ?? "")
            .hasPrefix("multipart/form-data")
    )
}

// ──────────────── entry ────────────────

@main
struct TestRunner {
    static func main() async {
        setbuf(stdout, nil)
        runSync()
        await runOpenAITests()
        await runCoordinatorE2E()
        let elapsed = Date().timeIntervalSince(start)
        print(String(format: "\n%d passed, %d failed in %.2fs", stats.passed, stats.failed, elapsed))
        exit(stats.failed == 0 ? 0 : 1)
    }
}
