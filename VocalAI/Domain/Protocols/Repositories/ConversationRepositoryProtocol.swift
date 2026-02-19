import Foundation

/// Abstracts streaming conversation responses. Absorbs configuration (systemPrompt, model).
protocol ConversationRepositoryProtocol: Sendable {
    func streamResponse(for messages: [ConversationMessage]) -> AsyncThrowingStream<String, Error>
}
