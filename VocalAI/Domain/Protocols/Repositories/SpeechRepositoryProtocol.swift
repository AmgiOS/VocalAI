import AVFoundation

/// Combines TTS synthesis and STT recognition behind a single abstraction.
protocol SpeechRepositoryProtocol: Sendable {
    func configureSynthesis() async throws
    func synthesize(text: String) async throws -> SynthesisResult

    @MainActor func startRecognition() throws -> AsyncStream<SpeechResult>
    @MainActor func appendRecognitionBuffer(_ buffer: AVAudioPCMBuffer)
    @MainActor func stopRecognition()
}
