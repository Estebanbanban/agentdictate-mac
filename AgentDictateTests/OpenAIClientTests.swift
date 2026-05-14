import XCTest
@testable import AgentDictate

private final class StubTransport: HTTPTransport {
    var nextResponse: (Data, URLResponse)?
    var nextError: Error?
    var lastRequest: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        if let err = nextError { throw err }
        guard let resp = nextResponse else {
            return (Data(), HTTPURLResponse(
                url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil
            )!)
        }
        return resp
    }
}

final class OpenAIClientTests: XCTestCase {

    private func okResponse(_ body: String, url: URL) -> (Data, URLResponse) {
        let data = body.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (data, response)
    }

    func testMissingKeyThrows() async {
        let client = OpenAIClient(transport: StubTransport(), apiKeyProvider: { nil })
        do {
            _ = try await client.transcribe(wav: Data())
            XCTFail("expected missing key error")
        } catch let error as OpenAIError {
            if case .missingAPIKey = error { return }
            XCTFail("wrong error: \(error)")
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    func testTranscribeReturnsText() async throws {
        let stub = StubTransport()
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        stub.nextResponse = okResponse(#"{"text":"hello world"}"#, url: url)
        let client = OpenAIClient(
            transport: stub,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            apiKeyProvider: { "sk-test" }
        )
        let text = try await client.transcribe(wav: Data([0x52, 0x49, 0x46, 0x46]))
        XCTAssertEqual(text, "hello world")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
        XCTAssertTrue(
            stub.lastRequest?.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data") ?? false
        )
    }

    func testCleanReturnsAssistantContent() async throws {
        let stub = StubTransport()
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        stub.nextResponse = okResponse(
            #"{"choices":[{"message":{"content":"cleaned text"}}]}"#,
            url: url
        )
        let client = OpenAIClient(
            transport: stub,
            apiKeyProvider: { "sk-test" }
        )
        let cleaned = try await client.clean(text: "raw", systemPrompt: "be concise")
        XCTAssertEqual(cleaned, "cleaned text")
    }

    func testHTTPErrorSurfacesStatusAndBody() async {
        let stub = StubTransport()
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        let body = #"{"error":"unauthorized"}"#
        stub.nextResponse = (
            body.data(using: .utf8)!,
            HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
        )
        let client = OpenAIClient(transport: stub, apiKeyProvider: { "sk-test" })
        do {
            _ = try await client.transcribe(wav: Data())
            XCTFail("expected error")
        } catch let OpenAIError.http(status, returnedBody) {
            XCTAssertEqual(status, 401)
            XCTAssertEqual(returnedBody, body)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }
}
