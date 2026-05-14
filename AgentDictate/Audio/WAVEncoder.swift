import Foundation

enum WAVEncoder {
    static func encode(samples: [Int16], sampleRate: Int, channels: Int = 1) -> Data {
        let bytesPerSample = 2
        let dataSize = samples.count * bytesPerSample
        let byteRate = sampleRate * channels * bytesPerSample
        let blockAlign = channels * bytesPerSample

        var data = Data()
        data.append(ascii: "RIFF")
        data.append(uint32LE: UInt32(36 + dataSize))
        data.append(ascii: "WAVE")
        data.append(ascii: "fmt ")
        data.append(uint32LE: 16)
        data.append(uint16LE: 1)
        data.append(uint16LE: UInt16(channels))
        data.append(uint32LE: UInt32(sampleRate))
        data.append(uint32LE: UInt32(byteRate))
        data.append(uint16LE: UInt16(blockAlign))
        data.append(uint16LE: 16)
        data.append(ascii: "data")
        data.append(uint32LE: UInt32(dataSize))

        samples.withUnsafeBufferPointer { ptr in
            if let base = ptr.baseAddress {
                data.append(UnsafeBufferPointer(start: base, count: ptr.count))
            }
        }
        return data
    }
}

private extension Data {
    mutating func append(ascii: String) {
        if let d = ascii.data(using: .ascii) { append(d) }
    }
    mutating func append(uint32LE value: UInt32) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
    mutating func append(uint16LE value: UInt16) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
    mutating func append(_ buffer: UnsafeBufferPointer<Int16>) {
        buffer.withMemoryRebound(to: UInt8.self) { bytes in
            append(bytes.baseAddress!, count: bytes.count)
        }
    }
}
