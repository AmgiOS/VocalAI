import Foundation

nonisolated enum Configuration {
    // MARK: - API Keys (stored in UserDefaults for development; use Keychain in production)

    static var azureSpeechKey: String {
        get { UserDefaultsStore.get("azure_speech_key", default: "") }
        set { UserDefaultsStore.set("azure_speech_key", value: newValue) }
    }

    static var azureSpeechRegion: String {
        get { UserDefaultsStore.get("azure_speech_region", default: "eastus") }
        set { UserDefaultsStore.set("azure_speech_region", value: newValue) }
    }

    static var claudeAPIKey: String {
        get { UserDefaultsStore.get("claude_api_key", default: "") }
        set { UserDefaultsStore.set("claude_api_key", value: newValue) }
    }

    // MARK: - Voice Settings

    static var azureVoiceName: String {
        get { UserDefaultsStore.get("azure_voice_name", default: "en-US-JennyNeural") }
        set { UserDefaultsStore.set("azure_voice_name", value: newValue) }
    }

    static var speechLanguage: String {
        get { UserDefaultsStore.get("speech_language", default: "en-US") }
        set { UserDefaultsStore.set("speech_language", value: newValue) }
    }

    // MARK: - Claude Settings

    static var claudeModel: String {
        get { UserDefaultsStore.get("claude_model", default: "claude-sonnet-4-6") }
        set { UserDefaultsStore.set("claude_model", value: newValue) }
    }

    static var systemPrompt: String {
        get { UserDefaultsStore.get("system_prompt", default: "You are a friendly, empathetic conversational partner. Respond naturally and concisely as if speaking face-to-face. Keep responses under 3 sentences unless asked for more detail.") }
        set { UserDefaultsStore.set("system_prompt", value: newValue) }
    }

    // MARK: - Avatar

    static let avatarAssetName = "avatar"
    static let avatarFallbackScale: Float = 0.01

    // MARK: - Animation

    static let breathingCycleDuration: Double = 4.0
    static let blinkIntervalRange: ClosedRange<Double> = 3.0...5.0
    static let blinkDuration: Double = 0.15
    static let emotionTransitionDuration: Double = 0.5
    static let lipSyncFrameRate: Double = 60.0

    // MARK: - Validation

    static var isAzureConfigured: Bool {
        !azureSpeechKey.isEmpty && !azureSpeechRegion.isEmpty
    }

    static var isClaudeConfigured: Bool {
        !claudeAPIKey.isEmpty
    }

    static var isFullyConfigured: Bool {
        isAzureConfigured && isClaudeConfigured
    }
}

// MARK: - UserDefaults Helper

private nonisolated enum UserDefaultsStore {
    static func get<V: Codable>(_ key: String, default defaultValue: V) -> V {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return defaultValue
        }
        return (try? JSONDecoder().decode(V.self, from: data)) ?? defaultValue
    }

    static func set<V: Codable>(_ key: String, value: V) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
