import Foundation

nonisolated enum ConversationState: String, Equatable, Sendable {
    case idle
    case listening
    case thinking
    case speaking
}
