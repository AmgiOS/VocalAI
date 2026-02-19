import Foundation

/// Abstraction for streaming chat completions from an LLM.
protocol ChatDataSourceProtocol: Sendable {
    func streamChat(
        messages: [ConversationMessage],
        systemPrompt: String,
        model: String
    ) async -> AsyncThrowingStream<String, Error>
}
