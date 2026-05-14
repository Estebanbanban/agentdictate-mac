import Foundation

struct MultipartBuilder {
    let boundary: String
    private var body = Data()

    init(boundary: String = "AgentDictate-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    mutating func appendField(name: String, value: String) {
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        body.append("\(value)\r\n")
    }

    mutating func appendFile(name: String, filename: String, mimeType: String, data: Data) {
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.append("\r\n")
    }

    func finalize() -> Data {
        var out = body
        out.append("--\(boundary)--\r\n")
        return out
    }

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) { append(data) }
    }
}
