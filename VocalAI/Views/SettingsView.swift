import SwiftUI

/// Settings view for configuring API keys, voice selection, and persona.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var azureKey = Configuration.azureSpeechKey
    @State private var azureRegion = Configuration.azureSpeechRegion
    @State private var claudeKey = Configuration.claudeAPIKey
    @State private var voiceName = Configuration.azureVoiceName
    @State private var language = Configuration.speechLanguage
    @State private var claudeModel = Configuration.claudeModel
    @State private var systemPrompt = Configuration.systemPrompt

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Azure Speech
                Section {
                    SecureField("Speech Key", text: $azureKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                    TextField("Region", text: $azureRegion)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Label("Azure Speech", systemImage: "waveform")
                } footer: {
                    Text("Required for text-to-speech and lip sync animation.")
                }

                // MARK: - Claude API
                Section {
                    SecureField("API Key", text: $claudeKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                    Picker("Model", selection: $claudeModel) {
                        Text("Claude Sonnet 4.6").tag("claude-sonnet-4-6")
                        Text("Claude Haiku 4.5").tag("claude-haiku-4-5-20251001")
                        Text("Claude Opus 4.6").tag("claude-opus-4-6")
                    }
                } header: {
                    Label("Claude AI", systemImage: "brain")
                } footer: {
                    Text("Required for AI conversation. Sonnet recommended for speed.")
                }

                // MARK: - Voice Settings
                Section {
                    Picker("Language", selection: $language) {
                        Text("English (US)").tag("en-US")
                        Text("English (UK)").tag("en-GB")
                        Text("French").tag("fr-FR")
                        Text("Spanish").tag("es-ES")
                        Text("German").tag("de-DE")
                        Text("Japanese").tag("ja-JP")
                    }
                    TextField("Voice Name", text: $voiceName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Label("Voice", systemImage: "speaker.wave.2")
                } footer: {
                    Text("Azure Neural Voice name. e.g., en-US-JennyNeural")
                }

                // MARK: - Persona
                Section {
                    TextEditor(text: $systemPrompt)
                        .frame(minHeight: 100)
                } header: {
                    Label("Persona", systemImage: "person")
                } footer: {
                    Text("System prompt that defines the avatar's personality.")
                }

                // MARK: - Status
                Section {
                    HStack {
                        Text("Azure")
                        Spacer()
                        Image(systemName: !azureKey.isEmpty ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(!azureKey.isEmpty ? .green : .red)
                    }
                    HStack {
                        Text("Claude")
                        Spacer()
                        Image(systemName: !claudeKey.isEmpty ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(!claudeKey.isEmpty ? .green : .red)
                    }
                } header: {
                    Label("Status", systemImage: "checkmark.shield")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveSettings() {
        Configuration.azureSpeechKey = azureKey
        Configuration.azureSpeechRegion = azureRegion
        Configuration.claudeAPIKey = claudeKey
        Configuration.azureVoiceName = voiceName
        Configuration.speechLanguage = language
        Configuration.claudeModel = claudeModel
        Configuration.systemPrompt = systemPrompt
    }
}

#Preview {
    SettingsView()
}
