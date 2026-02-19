import Foundation
import AVFoundation
import Observation
import Dependencies

/// Orchestrates the full conversation pipeline:
/// listening → thinking → speaking → idle
///
/// Uses a single `State` struct for all observable UI state.
/// Dependencies are injected via TCA Dependencies.
@Observable
@MainActor
final class ConversationViewModel {
    // MARK: - State

    struct State: Equatable {
        var conversationState: ConversationState = .idle
        var messages: [ConversationMessage] = []
        var partialTranscript = ""
        var currentResponseText = ""
        var errorMessage: String?
        var currentEmotion: EmotionType = .neutral
    }

    var state = State()

    // MARK: - Dependencies (not observed)

    @ObservationIgnored @Dependency(\.conversationUseCase) private var conversationUseCase
    @ObservationIgnored @Dependency(\.speechRepository) private var speechRepository
    @ObservationIgnored @Dependency(\.audioManager) private var audioManager

    @ObservationIgnored let animationMixer = AnimationMixer()
    @ObservationIgnored private var currentTask: Task<Void, Never>?
    @ObservationIgnored private var micListenTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func setup() async {
        do {
            try await speechRepository.configureSynthesis()
        } catch {
            state.errorMessage = error.localizedDescription
        }

        do {
            try audioManager.startEngine()
        } catch {
            state.errorMessage = "Audio engine failed: \(error.localizedDescription)"
        }
    }

    func teardown() {
        stopConversation()
        audioManager.stopEngine()
        animationMixer.stop()
    }

    // MARK: - Conversation Control

    /// Start listening for user speech.
    func startListening() {
        guard state.conversationState == .idle else { return }
        state.conversationState = .listening
        state.partialTranscript = ""
        state.errorMessage = nil

        do {
            let speechStream = try speechRepository.startRecognition()
            let micStream = audioManager.startMicCapture()

            // Forward mic buffers to the speech recognizer
            micListenTask = Task {
                for await buffer in micStream {
                    await speechRepository.appendRecognitionBuffer(buffer)
                }
            }

            // Consume speech recognition results
            currentTask = Task {
                for await result in speechStream {
                    switch result {
                    case .partial(let text):
                        state.partialTranscript = text

                    case .final(let text):
                        state.partialTranscript = text
                        audioManager.stopMicCapture()
                        micListenTask?.cancel()
                        await processUserMessage(text)
                        return
                    }
                }
            }

        } catch {
            state.errorMessage = error.localizedDescription
            state.conversationState = .idle
        }
    }

    /// Stop listening manually and process whatever was captured.
    func stopListening() {
        guard state.conversationState == .listening else { return }
        audioManager.stopMicCapture()
        micListenTask?.cancel()
        speechRepository.stopRecognition()

        let transcript = state.partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            state.conversationState = .idle
            return
        }

        currentTask = Task {
            await processUserMessage(transcript)
        }
    }

    /// Cancel any ongoing processing and return to idle.
    func stopConversation() {
        currentTask?.cancel()
        currentTask = nil
        micListenTask?.cancel()
        micListenTask = nil
        audioManager.stopPlayback()
        audioManager.stopMicCapture()
        speechRepository.stopRecognition()
        animationMixer.lipSyncEngine.stop()
        state.conversationState = .idle
        state.currentEmotion = .neutral
        animationMixer.emotionEngine.reset()
    }

    // MARK: - Pipeline

    private func processUserMessage(_ text: String) async {
        let userMessage = ConversationMessage(role: .user, content: text)
        state.messages.append(userMessage)
        state.partialTranscript = ""

        await thinkAndSpeak()
    }

    private func thinkAndSpeak() async {
        state.conversationState = .thinking
        state.currentResponseText = ""

        var fullResponse = ""

        do {
            let pipeline = conversationUseCase.thinkAndSynthesize(messages: state.messages)
            for try await event in pipeline {
                guard !Task.isCancelled else { return }

                switch event {
                case .textChunk(let chunk):
                    fullResponse += chunk
                    state.currentResponseText = fullResponse

                case .responseComplete(let displayText, let emotion):
                    state.messages.append(ConversationMessage(role: .assistant, content: displayText))
                    state.currentEmotion = emotion
                    animationMixer.emotionEngine.setEmotion(emotion)
                    state.conversationState = .speaking

                case .synthesisComplete(let result):
                    // Load viseme data and start lip sync
                    animationMixer.lipSyncEngine.load(result.visemeData)
                    animationMixer.lipSyncEngine.play()

                    // Play audio (suspends until playback completes)
                    let format = audioManager.speechOutputFormat
                    await audioManager.playAudioData(result.audioData, format: format)

                    // Ensure lip sync also finishes
                    await animationMixer.lipSyncEngine.waitForCompletion()
                }
            }
        } catch {
            state.errorMessage = error.localizedDescription
        }

        // Return to idle
        state.conversationState = .idle
        state.currentEmotion = .neutral
        animationMixer.emotionEngine.setEmotion(.neutral)
    }
}
