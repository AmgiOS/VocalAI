import Foundation

/// Mock use case for previews and tests.
struct MockConversationUseCase: ConversationUseCaseProtocol, Sendable {
    var events: [ConversationPipelineEvent]

    init(events: [ConversationPipelineEvent] = [
        .textChunk("Hello there! "),
        .textChunk("How can I help you today?"),
        .responseComplete(
            displayText: "Hello there! How can I help you today?",
            emotion: .happy
        ),
        .synthesisComplete(SynthesisResult(audioData: Data(), visemeData: VisemeData(frames: [])))
    ]) {
        self.events = events
    }

    func thinkAndSynthesize(
        messages: [ConversationMessage]
    ) -> AsyncThrowingStream<ConversationPipelineEvent, Error> {
        let events = self.events
        return AsyncThrowingStream { continuation in
            Task {
                for event in events {
                    try? await Task.sleep(for: .milliseconds(50))
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }
    }
}
