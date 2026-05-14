#!/usr/bin/env swift
// Plain-Swift test runner — no XCTest. Mirrors the XCTest suite so we can
// run unit tests without full Xcode installed (XCTest ships with Xcode).
// Run: swift tests-no-xcode/run-tests.swift

import Foundation
import CoreGraphics

// Re-import production sources by compiling them together.
// Build runner usage: swift -I AgentDictate ... is awkward; instead use the
// scripts/run-tests.sh wrapper which globs source paths.

var failed = 0
var passed = 0
let start = Date()

func check(_ name: String, _ condition: @autoclosure () -> Bool, _ msg: String = "") {
    if condition() {
        passed += 1
        print("  ✓ \(name)")
    } else {
        failed += 1
        print("  ✗ \(name) \(msg)")
    }
}

func describe(_ group: String, _ block: () -> Void) {
    print("\n\(group)")
    block()
}

// ──────────────── ReplacementsEngine ────────────────

describe("ReplacementsEngine") {
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
    let regexOut = ReplacementsEngine.apply("It costs 50 dollars and 20 dollars", rules: [regex])
    check("regex captures + template",
          regexOut == "It costs $50 and $20",
          "got: \(regexOut)")

    let bad = ReplacementRule(pattern: "(unterminated", replacement: "x", mode: .regex)
    check("invalid regex leaves input",
          ReplacementsEngine.apply("hello", rules: [bad]) == "hello")

    let empty = ReplacementRule(pattern: "", replacement: "x")
    check("empty pattern is noop",
          ReplacementsEngine.apply("hello", rules: [empty]) == "hello")
}

// ──────────────── HotkeyBinding ────────────────

describe("HotkeyBinding") {
    let def = HotkeyBinding.default
    check("default is option+space",
          def.displayString.contains("⌥") && def.displayString.contains("Space"))

    let cmdShift = HotkeyBinding(
        keyCode: 0x09, // V
        modifiers: CGEventFlags.maskCommand.union(.maskShift).rawValue
    )
    check("display order ⇧⌘",
          cmdShift.displayString.contains("⇧") && cmdShift.displayString.contains("⌘"))

    let encoded = try? JSONEncoder().encode(def)
    let decoded = encoded.flatMap { try? JSONDecoder().decode(HotkeyBinding.self, from: $0) }
    check("codable roundtrip", decoded == def)
}

// ──────────────── WAVEncoder ────────────────

describe("WAVEncoder") {
    let samples: [Int16] = [0, 100, -100, 32000, -32000]
    let data = WAVEncoder.encode(samples: samples, sampleRate: 16000)
    let header = data.prefix(4)
    check("starts with RIFF", header == Data("RIFF".utf8))
    let waveTag = data.subdata(in: 8..<12)
    check("WAVE tag at offset 8", waveTag == Data("WAVE".utf8))
    let expectedSize = 44 + samples.count * 2
    check("total size matches", data.count == expectedSize)
}

// ──────────────── MultipartBuilder ────────────────

describe("MultipartBuilder") {
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

// ──────────────── OpenAIClient (mocked transport) ────────────────

private final class StubTransport: HTTPTransport {
    var nextData: Data = Data()
    var nextStatus: Int = 200
    var lastRequest: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: nextStatus,
            httpVersion: nil,
            headerFields: nil
        )!
        return (nextData, response)
    }
}

let group = DispatchGroup()
group.enter()
Task {
    let stub = StubTransport()
    stub.nextData = #"{"text":"hello world"}"#.data(using: .utf8)!
    let client = OpenAIClient(transport: stub, apiKeyProvider: { "sk-test" })
    do {
        let text = try await client.transcribe(wav: Data([0x52, 0x49, 0x46, 0x46]))
        describe("OpenAIClient") {
            check("transcribe returns text", text == "hello world")
            check("Authorization header set",
                  stub.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
            check("multipart Content-Type",
                  (stub.lastRequest?.value(forHTTPHeaderField: "Content-Type") ?? "").hasPrefix("multipart/form-data"))
        }
    } catch {
        describe("OpenAIClient") {
            check("transcribe returns text", false, "threw: \(error)")
        }
    }

    do {
        let stub2 = StubTransport()
        let client2 = OpenAIClient(transport: stub2, apiKeyProvider: { nil })
        _ = try await client2.transcribe(wav: Data())
        describe("OpenAIClient missing key") {
            check("expected throw", false)
        }
    } catch let OpenAIError.missingAPIKey {
        describe("OpenAIClient missing key") {
            check("throws missingAPIKey", true)
        }
    } catch {
        describe("OpenAIClient missing key") {
            check("throws missingAPIKey", false, "got: \(error)")
        }
    }

    do {
        let stub3 = StubTransport()
        stub3.nextStatus = 401
        stub3.nextData = #"{"error":"unauthorized"}"#.data(using: .utf8)!
        let client3 = OpenAIClient(transport: stub3, apiKeyProvider: { "sk-test" })
        _ = try await client3.transcribe(wav: Data())
        describe("OpenAIClient http error") {
            check("expected throw", false)
        }
    } catch let OpenAIError.http(status, body) {
        describe("OpenAIClient http error") {
            check("401 surfaces", status == 401)
            check("body included", body.contains("unauthorized"))
        }
    } catch {
        describe("OpenAIClient http error") {
            check("expected http error", false, "got: \(error)")
        }
    }

    group.leave()
}
group.wait()

// ──────────────── summary ────────────────

let elapsed = Date().timeIntervalSince(start)
print(String(format: "\n%d passed, %d failed in %.2fs", passed, failed, elapsed))
exit(failed == 0 ? 0 : 1)
