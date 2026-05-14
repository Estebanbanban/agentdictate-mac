import Foundation

enum OpenAIError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case http(status: Int, body: String)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key not set. Add it in Settings → OpenAI."
        case .invalidResponse:
            return "Unexpected response from OpenAI."
        case .http(let status, let body):
            return "OpenAI HTTP \(status): \(body)"
        case .decoding(let err):
            return "Failed to decode OpenAI response: \(err.localizedDescription)"
        case .transport(let err):
            return "Network error: \(err.localizedDescription)"
        }
    }
}
