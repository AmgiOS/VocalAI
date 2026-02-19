import Foundation

/// Orchestrates the conversation pipeline: stream LLM response, analyze emotion, synthesize speech.
protocol ConversationUseCaseProtocol: Sendable {
    func thinkAndSynthesize(
        messages: [ConversationMessage]
    ) -> AsyncThrowingStream<ConversationPipelineEvent, Error>
}
