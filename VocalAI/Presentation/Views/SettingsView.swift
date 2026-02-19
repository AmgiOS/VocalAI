import SwiftUI

/// Settings view for configuring API keys, voice selection, and persona.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Azure Speech
                Section {
                    SecureField("Speech Key", text: $viewModel.state.azureKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                    TextField("Region", text: $viewModel.state.azureRegion)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Label("Azure Speech", systemImage: "waveform")
                } footer: {
                    Text("Required for text-to-speech and lip sync animation.")
                }

                // MARK: - Claude API
                Section {
                    SecureField("API Key", text: $viewModel.state.claudeKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                    Picker("Model", selection: $viewModel.state.claudeModel) {
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
                    Picker("Language", selection: $viewModel.state.language) {
                        Text("English (US)").tag("en-US")
                        Text("English (UK)").tag("en-GB")
                        Text("French").tag("fr-FR")
                        Text("Spanish").tag("es-ES")
                        Text("German").tag("de-DE")
                        Text("Japanese").tag("ja-JP")
                    }
                    TextField("Voice Name", text: $viewModel.state.voiceName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Label("Voice", systemImage: "speaker.wave.2")
                } footer: {
                    Text("Azure Neural Voice name. e.g., en-US-JennyNeural")
                }

                // MARK: - Persona
                Section {
                    TextEditor(text: $viewModel.state.systemPrompt)
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
                        Image(systemName: !viewModel.state.azureKey.isEmpty ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(!viewModel.state.azureKey.isEmpty ? .green : .red)
                    }
                    HStack {
                        Text("Claude")
                        Spacer()
                        Image(systemName: !viewModel.state.claudeKey.isEmpty ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(!viewModel.state.claudeKey.isEmpty ? .green : .red)
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
                        viewModel.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
