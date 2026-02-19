import SwiftUI
import Dependencies

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
                StatusIndicator(state: viewModel.state.conversationState)
                    .padding(.bottom, 8)

                // Chat transcript
                ChatOverlayView(
                    messages: viewModel.state.messages,
                    partialTranscript: viewModel.state.partialTranscript,
                    currentResponse: viewModel.state.currentResponseText,
                    state: viewModel.state.conversationState
                )
                .frame(maxHeight: 200)
                .padding(.horizontal, 16)

                // Microphone button
                MicrophoneButton(
                    state: viewModel.state.conversationState,
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
            if let error = viewModel.state.errorMessage {
                VStack {
                    ErrorBanner(message: error) {
                        viewModel.state.errorMessage = nil
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
            viewModel.state.errorMessage = "Failed to load avatar: \(error.localizedDescription)"
        }
    }
}

#Preview {
    withDependencies {
        $0.conversationUseCase = MockConversationUseCase()
        $0.speechRepository = MockSpeechRepository()
        $0.audioManager = AudioManager()
    } operation: {
        ConversationView()
            .environment(AppState())
    }
}
