import Foundation

enum Configuration {
    // MARK: - API Keys (stored in UserDefaults for development; use Keychain in production)

    @AppStorageBacked(key: "azure_speech_key", defaultValue: "")
    static var azureSpeechKey: String

    @AppStorageBacked(key: "azure_speech_region", defaultValue: "eastus")
    static var azureSpeechRegion: String

    @AppStorageBacked(key: "claude_api_key", defaultValue: "")
    static var claudeAPIKey: String

    // MARK: - Voice Settings

    @AppStorageBacked(key: "azure_voice_name", defaultValue: "en-US-JennyNeural")
    static var azureVoiceName: String

    @AppStorageBacked(key: "speech_language", defaultValue: "en-US")
    static var speechLanguage: String

    // MARK: - Claude Settings

    @AppStorageBacked(key: "claude_model", defaultValue: "claude-sonnet-4-6")
    static var claudeModel: String

    @AppStorageBacked(key: "system_prompt", defaultValue: "You are a friendly, empathetic conversational partner. Respond naturally and concisely as if speaking face-to-face. Keep responses under 3 sentences unless asked for more detail.")
    static var systemPrompt: String

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

// MARK: - Property Wrapper for UserDefaults-backed static properties

@propertyWrapper
struct AppStorageBacked<Value: Codable> {
    let key: String
    let defaultValue: Value

    var wrappedValue: Value {
        get {
            guard let data = UserDefaults.standard.data(forKey: key) else {
                return defaultValue
            }
            return (try? JSONDecoder().decode(Value.self, from: data)) ?? defaultValue
        }
        nonmutating set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }
}
