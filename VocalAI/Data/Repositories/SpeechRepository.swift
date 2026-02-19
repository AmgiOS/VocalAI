import AVFoundation

/// Concrete implementation of `SpeechRepositoryProtocol`.
/// Combines TTS (Azure) and STT (Apple) behind a single interface.
final class SpeechRepository: SpeechRepositoryProtocol, @unchecked Sendable {
    private let synthesisDataSource: SpeechSynthesisDataSourceProtocol
    @MainActor private let recognitionDataSource: SpeechRecognitionDataSourceProtocol

    @MainActor
    init(
        synthesisDataSource: SpeechSynthesisDataSourceProtocol,
        recognitionDataSource: SpeechRecognitionDataSourceProtocol
    ) {
        self.synthesisDataSource = synthesisDataSource
        self.recognitionDataSource = recognitionDataSource
    }

    func configureSynthesis() async throws {
        try await synthesisDataSource.configure()
    }

    func synthesize(text: String) async throws -> SynthesisResult {
        try await synthesisDataSource.synthesize(
            text: text,
            voiceName: Configuration.azureVoiceName
        )
    }

    @MainActor
    func startRecognition() throws -> AsyncStream<SpeechResult> {
        try recognitionDataSource.startRecognition()
    }

    @MainActor
    func appendRecognitionBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionDataSource.appendBuffer(buffer)
    }

    @MainActor
    func stopRecognition() {
        recognitionDataSource.stopRecognition()
    }
}
