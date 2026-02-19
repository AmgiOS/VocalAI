import Foundation

/// Concrete implementation of `ConversationRepositoryProtocol`.
/// Absorbs Configuration values (systemPrompt, model) so callers don't need them.
struct ConversationRepository: ConversationRepositoryProtocol, Sendable {
    private let chatDataSource: ChatDataSourceProtocol

    init(chatDataSource: ChatDataSourceProtocol) {
        self.chatDataSource = chatDataSource
    }

    func streamResponse(for messages: [ConversationMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = await chatDataSource.streamChat(
                        messages: messages,
                        systemPrompt: Configuration.systemPrompt,
                        model: Configuration.claudeModel
                    )
                    for try await chunk in stream {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
