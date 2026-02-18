import AVFoundation

/// Manages AVAudioEngine for microphone capture and audio playback.
@MainActor
final class AudioManager {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var isMicTapInstalled = false

    var isPlaying: Bool { playerNode.isPlaying }
    var onMicBuffer: ((_ buffer: AVAudioPCMBuffer, _ time: AVAudioTime) -> Void)?
    var onPlaybackComplete: (() -> Void)?

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

    func startMicCapture() {
        guard !isMicTapInstalled else { return }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            self?.onMicBuffer?(buffer, time)
        }
        isMicTapInstalled = true
    }

    func stopMicCapture() {
        guard isMicTapInstalled else { return }
        engine.inputNode.removeTap(onBus: 0)
        isMicTapInstalled = false
    }

    // MARK: - Audio Playback

    /// Play raw PCM audio data. Returns immediately; calls onPlaybackComplete when done.
    func playAudioData(_ data: Data, format: AVAudioFormat) {
        guard let buffer = createBuffer(from: data, format: format) else { return }
        playBuffer(buffer)
    }

    /// Play an audio buffer directly.
    func playBuffer(_ buffer: AVAudioPCMBuffer) {
        stopPlayback()

        // Reconnect player with the buffer's format
        engine.disconnectNodeOutput(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: buffer.format)

        playerNode.scheduleBuffer(buffer) { [weak self] in
            Task { @MainActor in
                self?.onPlaybackComplete?()
            }
        }
        playerNode.play()
    }

    /// Stop current audio playback.
    func stopPlayback() {
        playerNode.stop()
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
