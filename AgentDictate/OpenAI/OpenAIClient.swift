import Foundation

protocol HTTPTransport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPTransport {}

struct OpenAIClient {
    let transport: HTTPTransport
    let apiKeyProvider: () throws -> String?
    let baseURL: URL

    init(
        transport: HTTPTransport = URLSession.shared,
        baseURL: URL? = nil,
        apiKeyProvider: (() throws -> String?)? = nil
    ) {
        self.transport = transport
        let env = ProcessInfo.processInfo.environment
        if let provided = baseURL {
            self.baseURL = provided
        } else if let override = env["AGENTDICTATE_OPENAI_BASE_URL"], let u = URL(string: override) {
            self.baseURL = u
        } else {
            self.baseURL = URL(string: "https://api.openai.com/v1")!
        }
        if let provider = apiKeyProvider {
            self.apiKeyProvider = provider
        } else if let envKey = env["AGENTDICTATE_OPENAI_API_KEY"], !envKey.isEmpty {
            self.apiKeyProvider = { envKey }
        } else {
            self.apiKeyProvider = { try KeychainStore().get(KeychainStore.openAIKeyAccount) }
        }
    }

    func transcribe(wav: Data, model: String = "whisper-1", language: String? = nil) async throws -> String {
        let key = try requireKey()
        var multipart = MultipartBuilder()
        multipart.appendField(name: "model", value: model)
        if let language { multipart.appendField(name: "language", value: language) }
        multipart.appendField(name: "response_format", value: "json")
        multipart.appendFile(name: "file", filename: "audio.wav", mimeType: "audio/wav", data: wav)

        var request = URLRequest(url: baseURL.appendingPathComponent("audio/transcriptions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue(multipart.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = multipart.finalize()

        let data = try await send(request)
        struct R: Decodable { let text: String }
        return try decode(R.self, from: data).text
    }

    func clean(
        text: String,
        systemPrompt: String,
        model: String = "gpt-4o-mini"
    ) async throws -> String {
        let key = try requireKey()
        struct Message: Encodable { let role: String; let content: String }
        struct Body: Encodable {
            let model: String
            let messages: [Message]
            let temperature: Double
        }
        let body = Body(
            model: model,
            messages: [
                Message(role: "system", content: systemPrompt),
                Message(role: "user", content: text)
            ],
            temperature: 0.2
        )

        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let data = try await send(request)
        struct R: Decodable {
            struct Choice: Decodable { struct M: Decodable { let content: String }; let message: M }
            let choices: [Choice]
        }
        return try decode(R.self, from: data).choices.first?.message.content ?? text
    }

    private func requireKey() throws -> String {
        guard let key = try apiKeyProvider(), !key.isEmpty else { throw OpenAIError.missingAPIKey }
        return key
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let response: (Data, URLResponse)
        do {
            response = try await transport.data(for: request)
        } catch {
            throw OpenAIError.transport(error)
        }
        guard let http = response.1 as? HTTPURLResponse else { throw OpenAIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: response.0, encoding: .utf8) ?? ""
            throw OpenAIError.http(status: http.statusCode, body: body)
        }
        return response.0
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw OpenAIError.decoding(error)
        }
    }
}
