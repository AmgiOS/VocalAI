import Foundation

/// Events emitted by the ConversationUseCase during the think-and-synthesize pipeline.
nonisolated enum ConversationPipelineEvent: Sendable {
    /// A partial text chunk from the Claude streaming response.
    case textChunk(String)

    /// The full response is complete, with display text and detected emotion.
    case responseComplete(displayText: String, emotion: EmotionType)

    /// TTS synthesis is complete with audio data and viseme frames.
    case synthesisComplete(SynthesisResult)
}
