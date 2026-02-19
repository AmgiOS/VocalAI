import Foundation

/// Orchestrates the conversation pipeline:
/// Stream Claude response → analyze emotion → synthesize speech.
/// Emits `ConversationPipelineEvent` as an async stream.
struct ConversationUseCase: ConversationUseCaseProtocol, Sendable {
    private let conversationRepository: ConversationRepositoryProtocol
    private let speechRepository: SpeechRepositoryProtocol
    private let emotionAnalysis: EmotionAnalysisUseCase

    init(
        conversationRepository: ConversationRepositoryProtocol,
        speechRepository: SpeechRepositoryProtocol,
        emotionAnalysis: EmotionAnalysisUseCase = .live
    ) {
        self.conversationRepository = conversationRepository
        self.speechRepository = speechRepository
        self.emotionAnalysis = emotionAnalysis
    }

    func thinkAndSynthesize(
        messages: [ConversationMessage]
    ) -> AsyncThrowingStream<ConversationPipelineEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Phase 1: Stream response from LLM
                    var fullResponse = ""

                    let stream = conversationRepository.streamResponse(for: messages)
                    for try await chunk in stream {
                        guard !Task.isCancelled else { return }
                        fullResponse += chunk
                        continuation.yield(.textChunk(chunk))
                    }

                    guard !Task.isCancelled, !fullResponse.isEmpty else {
                        continuation.finish()
                        return
                    }

                    // Strip emotion tags for display
                    let displayText = fullResponse.replacingOccurrences(
                        of: #"\[emotion:\w+\]"#,
                        with: "",
                        options: .regularExpression
                    ).trimmingCharacters(in: .whitespacesAndNewlines)

                    // Analyze emotion
                    let emotion = emotionAnalysis.analyze(fullResponse)
                    continuation.yield(.responseComplete(displayText: displayText, emotion: emotion))

                    // Phase 2: Synthesize speech
                    let result = try await speechRepository.synthesize(text: displayText)
                    guard !Task.isCancelled else {
                        continuation.finish()
                        return
                    }
                    continuation.yield(.synthesisComplete(result))

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
