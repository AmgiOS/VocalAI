import AVFoundation

/// Wraps `SpeechRecognitionService` behind the `SpeechRecognitionDataSourceProtocol`.
@MainActor
final class AppleSpeechRecognitionDataSource: SpeechRecognitionDataSourceProtocol {
    private let service = SpeechRecognitionService()

    var isRecognizing: Bool { service.isRecognizing }

    func startRecognition() throws -> AsyncStream<SpeechResult> {
        try service.startRecognition()
    }

    func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        service.appendBuffer(buffer)
    }

    func stopRecognition() {
        service.stopRecognition()
    }
}
