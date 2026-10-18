import AVFoundation

/// Captures only during an explicitly started voice session; no audio is saved.
final class AudioCapture {
    private let engine = AVAudioEngine()
    private var tapped = false
    var onPCM: ((Data) -> Void)?
    var onFailure: ((String) -> Void)?

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true)
        let input = engine.inputNode
        let source = input.outputFormat(forBus: 0)
        guard source.sampleRate > 0, source.channelCount > 0,
              let target = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 8000,
                                         channels: 1, interleaved: true),
              let converter = AVAudioConverter(from: source, to: target) else {
            throw AppFailure.message("Mikrofonen kunde inte förberedas.")
        }
        input.installTap(onBus: 0, bufferSize: 4096, format: source) { [weak self] buffer, _ in
            let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * 8000 / source.sampleRate) + 32)
            guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
            var provided = false
            var error: NSError?
            let status = converter.convert(to: output, error: &error) { _, inputStatus in
                if provided { inputStatus.pointee = .noDataNow; return nil }
                provided = true; inputStatus.pointee = .haveData
                return buffer
            }
            if status == .error {
                DispatchQueue.main.async { self?.onFailure?("Ljudet kunde inte läsas från mikrofonen.") }
                return
            }
            guard output.frameLength > 0, let bytes = output.int16ChannelData?[0] else { return }
            let pcm = Data(bytes: bytes, count: Int(output.frameLength) * 2)
            DispatchQueue.main.async { self?.onPCM?(pcm) }
        }
        tapped = true
        engine.prepare()
        do { try engine.start() }
        catch { stop(); throw error }
    }
    func stop() {
        engine.stop()
        if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
