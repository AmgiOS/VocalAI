import Foundation

/// Wraps `AzureSpeechService` behind the `SpeechSynthesisDataSourceProtocol`.
struct AzureSpeechSynthesisDataSource: SpeechSynthesisDataSourceProtocol, Sendable {
    private let service = AzureSpeechService()

    func configure() async throws {
        try await service.configure()
    }

    func synthesize(text: String, voiceName: String) async throws -> SynthesisResult {
        try await service.synthesize(text: text, voiceName: voiceName)
    }
}
