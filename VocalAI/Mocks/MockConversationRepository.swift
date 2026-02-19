import Foundation

/// Mock repository that returns a canned streaming response.
struct MockConversationRepository: ConversationRepositoryProtocol, Sendable {
    var responseChunks: [String]

    init(responseChunks: [String] = ["Hello", " there!", " How", " can", " I", " help?"]) {
        self.responseChunks = responseChunks
    }

    func streamResponse(for messages: [ConversationMessage]) -> AsyncThrowingStream<String, Error> {
        let chunks = responseChunks
        return AsyncThrowingStream { continuation in
            Task {
                for chunk in chunks {
                    try? await Task.sleep(for: .milliseconds(50))
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }
}
