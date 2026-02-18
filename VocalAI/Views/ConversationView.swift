import SwiftUI

/// Main view composing the avatar, chat overlay, and microphone button.
struct ConversationView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ConversationViewModel()
    @State private var renderer = AvatarRenderer()
    @State private var avatarLoaded = false

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // 3D Avatar
            AvatarContainerView(renderer: renderer)
                .ignoresSafeArea()

            // Chat overlay + controls
            VStack(spacing: 0) {
                Spacer()

                // Status indicator
                statusIndicator
                    .padding(.bottom, 8)

                // Chat transcript
                ChatOverlayView(
                    messages: viewModel.messages,
                    partialTranscript: viewModel.partialTranscript,
                    currentResponse: viewModel.currentResponseText,
                    state: viewModel.conversationState
                )
                .frame(maxHeight: 200)
                .padding(.horizontal, 16)

                // Microphone button
                MicrophoneButton(
                    state: viewModel.conversationState,
                    onTapDown: { viewModel.startListening() },
                    onTapUp: { viewModel.stopListening() },
                    onCancel: { viewModel.stopConversation() }
                )
                .padding(.bottom, 20)
                .padding(.top, 12)
            }

            // Settings button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        appState.showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                Spacer()
            }

            // Error banner
            if let error = viewModel.errorMessage {
                VStack {
                    ErrorBanner(message: error) {
                        viewModel.errorMessage = nil
                    }
                    Spacer()
                }
                .padding(.top, 60)
                .transition(.move(edge: .top))
            }
        }
        .sheet(isPresented: Bindable(appState).showSettings) {
            SettingsView()
        }
        .task {
            await loadAvatar()
            await viewModel.setup()
        }
        .onDisappear {
            viewModel.teardown()
        }
    }

    // MARK: - Status Indicator

    @ViewBuilder
    private var statusIndicator: some View {
        switch viewModel.conversationState {
        case .idle:
            EmptyView()
        case .listening:
            Label("Listening...", systemImage: "waveform")
                .font(.caption)
                .foregroundStyle(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.green.opacity(0.15), in: Capsule())
        case .thinking:
            Label("Thinking...", systemImage: "brain")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.15), in: Capsule())
        case .speaking:
            Label("Speaking...", systemImage: "speaker.wave.2")
                .font(.caption)
                .foregroundStyle(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.blue.opacity(0.15), in: Capsule())
        }
    }

    // MARK: - Avatar Loading

    private func loadAvatar() async {
        do {
            try await renderer.loadAvatar()
            avatarLoaded = true
            appState.isAvatarLoaded = true

            // Attach animation mixer to blend shape controller
            if let controller = renderer.blendShapeController {
                viewModel.animationMixer.attach(to: controller)
                viewModel.animationMixer.start()
            }
        } catch {
            viewModel.errorMessage = "Failed to load avatar: \(error.localizedDescription)"
        }
    }
}

// MARK: - Error Banner

private struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(12)
        .background(.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}

#Preview {
    ConversationView()
        .environment(AppState())
}
