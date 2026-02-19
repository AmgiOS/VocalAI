import Foundation

/// Wraps `ClaudeService` behind the `ChatDataSourceProtocol`.
struct ClaudeChatDataSource: ChatDataSourceProtocol, Sendable {
    private let service = ClaudeService()

    func streamChat(
        messages: [ConversationMessage],
        systemPrompt: String,
        model: String
    ) async -> AsyncThrowingStream<String, Error> {
        await service.streamChat(messages: messages, systemPrompt: systemPrompt, model: model)
    }
}
