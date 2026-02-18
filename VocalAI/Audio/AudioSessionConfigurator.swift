import AVFoundation

enum AudioSessionConfigurator {
    /// Configure the audio session for voice chat (mic + speaker, echo cancellation).
    static func configureForVoiceChat() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [
            .defaultToSpeaker,
            .allowBluetooth,
            .allowBluetoothA2DP
        ])
        try session.setActive(true)
    }

    /// Configure for playback only (no mic).
    static func configureForPlayback() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    /// Deactivate the audio session.
    static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Request microphone permission.
    static func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
}
