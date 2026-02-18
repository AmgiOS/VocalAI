import SwiftUI

enum ConversationState: Equatable {
    case idle
    case listening
    case thinking
    case speaking
}

@Observable
final class AppState {
    var conversationState: ConversationState = .idle
    var currentEmotion: EmotionType = .neutral
    var isMicrophoneAuthorized = false
    var isSpeechRecognitionAuthorized = false
    var errorMessage: String?
    var showSettings = false

    var isAvatarLoaded = false
    var partialTranscript = ""
    var currentResponseText = ""
}
