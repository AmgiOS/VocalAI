import Foundation

/// Abstraction for text-to-speech synthesis with viseme data.
protocol SpeechSynthesisDataSourceProtocol: Sendable {
    func configure() async throws
    func synthesize(text: String, voiceName: String) async throws -> SynthesisResult
}
