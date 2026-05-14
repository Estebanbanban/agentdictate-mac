import AVFoundation
import Foundation

@MainActor
final class AudioRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var levels: [Float] = []

    private let engine = AVAudioEngine()
    private let targetSampleRate: Double = 16_000
    private var collected: [Int16] = []
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?

    func start() throws {
        guard !isRecording else { return }
        collected.removeAll(keepingCapacity: true)
        levels.removeAll(keepingCapacity: true)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let target = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: true
        ) else {
            throw NSError(domain: "AudioRecorder", code: 1)
        }
        targetFormat = target
        converter = AVAudioConverter(from: inputFormat, to: target)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.handle(buffer: buffer)
        }
        engine.prepare()
        try engine.start()
        isRecording = true
    }

    func stop() -> Data {
        guard isRecording else { return Data() }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        return WAVEncoder.encode(samples: collected, sampleRate: Int(targetSampleRate))
    }

    private func handle(buffer: AVAudioPCMBuffer) {
        let rms = computeRMS(buffer)
        Task { @MainActor in self.pushLevel(rms) }

        guard let converter, let targetFormat else { return }
        let capacity = AVAudioFrameCount(targetFormat.sampleRate) // 1s of target frames as upper bound
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }
        var error: NSError?
        var supplied = false
        converter.convert(to: out, error: &error) { _, status in
            if supplied {
                status.pointee = .endOfStream
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, let channel = out.int16ChannelData?[0] else { return }
        let frameCount = Int(out.frameLength)
        let chunk = UnsafeBufferPointer(start: channel, count: frameCount)
        Task { @MainActor in self.collected.append(contentsOf: chunk) }
    }

    private func computeRMS(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0] else {
            if let i16 = buffer.int16ChannelData?[0] {
                let count = Int(buffer.frameLength)
                var sum: Float = 0
                for i in 0..<count {
                    let s = Float(i16[i]) / Float(Int16.max)
                    sum += s * s
                }
                return sqrt(sum / Float(max(count, 1)))
            }
            return 0
        }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<count { sum += data[i] * data[i] }
        return sqrt(sum / Float(max(count, 1)))
    }

    private func pushLevel(_ rms: Float) {
        let normalized = min(1, max(0, rms * 4))
        levels.append(normalized)
        if levels.count > 96 { levels.removeFirst(levels.count - 96) }
    }
}
