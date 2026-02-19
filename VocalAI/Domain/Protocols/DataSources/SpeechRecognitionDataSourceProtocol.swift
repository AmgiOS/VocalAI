import AVFoundation

/// Abstraction for speech-to-text recognition.
@MainActor
protocol SpeechRecognitionDataSourceProtocol {
    var isRecognizing: Bool { get }
    func startRecognition() throws -> AsyncStream<SpeechResult>
    func appendBuffer(_ buffer: AVAudioPCMBuffer)
    func stopRecognition()
}
