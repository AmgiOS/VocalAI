import Dependencies
import Foundation

// MARK: - ConversationRepository

extension DependencyValues {
    var conversationRepository: ConversationRepositoryProtocol {
        get { self[ConversationRepositoryKey.self] }
        set { self[ConversationRepositoryKey.self] = newValue }
    }
}

private struct ConversationRepositoryKey: DependencyKey {
    static let liveValue: ConversationRepositoryProtocol = ConversationRepository(
        chatDataSource: ClaudeChatDataSource()
    )
}

// MARK: - SpeechRepository

extension DependencyValues {
    var speechRepository: SpeechRepositoryProtocol {
        get { self[SpeechRepositoryKey.self] }
        set { self[SpeechRepositoryKey.self] = newValue }
    }
}

private struct SpeechRepositoryKey: DependencyKey {
    @MainActor static let liveValue: SpeechRepositoryProtocol = SpeechRepository(
        synthesisDataSource: AzureSpeechSynthesisDataSource(),
        recognitionDataSource: AppleSpeechRecognitionDataSource()
    )
}
