import AVFoundation

/// Mock speech repository for previews and tests.
final class MockSpeechRepository: SpeechRepositoryProtocol, @unchecked Sendable {
    func configureSynthesis() async throws {
        // No-op
    }

    func synthesize(text: String) async throws -> SynthesisResult {
        SynthesisResult(audioData: Data(), visemeData: VisemeData(frames: []))
    }

    @MainActor
    func startRecognition() throws -> AsyncStream<SpeechResult> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    @MainActor
    func appendRecognitionBuffer(_ buffer: AVAudioPCMBuffer) {
        // No-op
    }

    @MainActor
    func stopRecognition() {
        // No-op
    }
}
