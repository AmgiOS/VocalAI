import SwiftUI

@Observable
final class AppState {
    var isMicrophoneAuthorized = false
    var isSpeechRecognitionAuthorized = false
    var showSettings = false
    var isAvatarLoaded = false
}
