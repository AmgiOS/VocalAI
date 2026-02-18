import AVFoundation

/// Manages AVAudioEngine for microphone capture and audio playback.
/// All async — mic capture via `AsyncStream`, playback via `async` functions.
@MainActor
final class AudioManager {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var isMicTapInstalled = false
    private var micContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    private var playbackContinuation: CheckedContinuation<Void, Never>?

    var isPlaying: Bool { playerNode.isPlaying }

    init() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
    }

    // MARK: - Engine Lifecycle

    func startEngine() throws {
        guard !engine.isRunning else { return }
        try AudioSessionConfigurator.configureForVoiceChat()
        try engine.start()
    }

    func stopEngine() {
        stopMicCapture()
        stopPlayback()
        engine.stop()
    }

    // MARK: - Microphone Capture

    /// Start capturing microphone audio. Returns an `AsyncStream` of PCM buffers.
    func startMicCapture() -> AsyncStream<AVAudioPCMBuffer> {
        stopMicCapture()

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        let stream = AsyncStream<AVAudioPCMBuffer> { continuation in
            self.micContinuation = continuation

            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.removeMicTap()
                }
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.micContinuation?.yield(buffer)
        }
        isMicTapInstalled = true

        return stream
    }

    /// Stop microphone capture and finish the stream.
    func stopMicCapture() {
        micContinuation?.finish()
        micContinuation = nil
        removeMicTap()
    }

    private func removeMicTap() {
        guard isMicTapInstalled else { return }
        engine.inputNode.removeTap(onBus: 0)
        isMicTapInstalled = false
    }

    // MARK: - Audio Playback

    /// Play raw PCM audio data. Suspends until playback completes.
    func playAudioData(_ data: Data, format: AVAudioFormat) async {
        guard let buffer = createBuffer(from: data, format: format) else { return }
        await playBuffer(buffer)
    }

    /// Play an audio buffer. Suspends until playback completes.
    func playBuffer(_ buffer: AVAudioPCMBuffer) async {
        stopPlayback()

        engine.disconnectNodeOutput(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: buffer.format)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.playbackContinuation = continuation

            playerNode.scheduleBuffer(buffer) { [weak self] in
                Task { @MainActor in
                    self?.playbackContinuation = nil
                    continuation.resume()
                }
            }
            playerNode.play()
        }
    }

    /// Stop current audio playback immediately.
    func stopPlayback() {
        playerNode.stop()
        playbackContinuation?.resume()
        playbackContinuation = nil
    }

    // MARK: - Audio Format

    /// Standard format for Azure Speech SDK output (16kHz, 16-bit mono PCM).
    var speechOutputFormat: AVAudioFormat {
        AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
    }

    /// Format matching the engine's input node (for speech recognition).
    var inputFormat: AVAudioFormat {
        engine.inputNode.outputFormat(forBus: 0)
    }

    // MARK: - Private

    private func createBuffer(from data: Data, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCount = UInt32(data.count) / format.streamDescription.pointee.mBytesPerFrame
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        data.withUnsafeBytes { rawBuffer in
            if let src = rawBuffer.baseAddress {
                memcpy(buffer.audioBufferList.pointee.mBuffers.mData, src, data.count)
            }
        }

        return buffer
    }
}
