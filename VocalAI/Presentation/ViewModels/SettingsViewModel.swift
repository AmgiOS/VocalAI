import Observation

/// ViewModel for the Settings screen with a single State struct.
@Observable
@MainActor
final class SettingsViewModel {
    struct State: Equatable {
        var azureKey: String
        var azureRegion: String
        var claudeKey: String
        var voiceName: String
        var language: String
        var claudeModel: String
        var systemPrompt: String
    }

    var state: State

    init() {
        state = State(
            azureKey: Configuration.azureSpeechKey,
            azureRegion: Configuration.azureSpeechRegion,
            claudeKey: Configuration.claudeAPIKey,
            voiceName: Configuration.azureVoiceName,
            language: Configuration.speechLanguage,
            claudeModel: Configuration.claudeModel,
            systemPrompt: Configuration.systemPrompt
        )
    }

    func save() {
        Configuration.azureSpeechKey = state.azureKey
        Configuration.azureSpeechRegion = state.azureRegion
        Configuration.claudeAPIKey = state.claudeKey
        Configuration.azureVoiceName = state.voiceName
        Configuration.speechLanguage = state.language
        Configuration.claudeModel = state.claudeModel
        Configuration.systemPrompt = state.systemPrompt
    }
}
