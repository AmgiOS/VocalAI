import Foundation

/// Result emitted by the speech recognition stream.
nonisolated enum SpeechResult: Sendable {
    case partial(String)
    case final(String)
}
