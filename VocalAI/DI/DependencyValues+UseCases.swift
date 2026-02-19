import Dependencies
import Foundation

// MARK: - ConversationUseCase

extension DependencyValues {
    var conversationUseCase: ConversationUseCaseProtocol {
        get { self[ConversationUseCaseKey.self] }
        set { self[ConversationUseCaseKey.self] = newValue }
    }
}

private struct ConversationUseCaseKey: DependencyKey {
    @MainActor static let liveValue: ConversationUseCaseProtocol = {
        @Dependency(\.conversationRepository) var conversationRepository
        @Dependency(\.speechRepository) var speechRepository
        return ConversationUseCase(
            conversationRepository: conversationRepository,
            speechRepository: speechRepository
        )
    }()
}

// MARK: - EmotionAnalysisUseCase

extension DependencyValues {
    var emotionAnalysis: EmotionAnalysisUseCase {
        get { self[EmotionAnalysisKey.self] }
        set { self[EmotionAnalysisKey.self] = newValue }
    }
}

private struct EmotionAnalysisKey: DependencyKey {
    static let liveValue = EmotionAnalysisUseCase.live
}
