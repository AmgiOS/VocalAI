import Foundation
import AVFoundation
import Observation

/// Orchestrates the full conversation pipeline:
/// listening → thinking → speaking → idle
///
/// All asynchronous operations use async/await and AsyncStream.
@Observable
@MainActor
final class ConversationViewModel {
    // MARK: - State

    var conversationState: ConversationState = .idle
    var messages: [ConversationMessage] = []
    var partialTranscript = ""
    var currentResponseText = ""
    var errorMessage: String?
    var currentEmotion: EmotionType = .neutral

    // MARK: - Dependencies

    let audioManager = AudioManager()
    let animationMixer = AnimationMixer()

    private let claudeService = ClaudeService()
    private let azureService = AzureSpeechService()
    private let speechService: SpeechRecognitionService
    private var currentTask: Task<Void, Never>?
    private var micListenTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        speechService = SpeechRecognitionService()
    }

    // MARK: - Lifecycle

    func setup() async {
        do {
            try await azureService.configure()
        } catch {
            errorMessage = error.localizedDescription
        }

        do {
            try audioManager.startEngine()
        } catch {
            errorMessage = "Audio engine failed: \(error.localizedDescription)"
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
        guard conversationState == .idle else { return }
        conversationState = .listening
        partialTranscript = ""
        errorMessage = nil

        do {
            let speechStream = try speechService.startRecognition()
            let micStream = audioManager.startMicCapture()

            // Forward mic buffers to the speech recognizer
            micListenTask = Task {
                for await buffer in micStream {
                    speechService.appendBuffer(buffer)
                }
            }

            // Consume speech recognition results
            currentTask = Task {
                for await result in speechStream {
                    switch result {
                    case .partial(let text):
                        partialTranscript = text

                    case .final(let text):
                        partialTranscript = text
                        audioManager.stopMicCapture()
                        micListenTask?.cancel()
                        await processUserMessage(text)
                        return
                    }
                }
            }

        } catch {
            errorMessage = error.localizedDescription
            conversationState = .idle
        }
    }

    /// Stop listening manually and process whatever was captured.
    func stopListening() {
        guard conversationState == .listening else { return }
        audioManager.stopMicCapture()
        micListenTask?.cancel()
        speechService.stopRecognition()

        let transcript = partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            conversationState = .idle
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
        speechService.stopRecognition()
        animationMixer.lipSyncEngine.stop()
        conversationState = .idle
        currentEmotion = .neutral
        animationMixer.emotionEngine.reset()
    }

    // MARK: - Pipeline

    private func processUserMessage(_ text: String) async {
        let userMessage = ConversationMessage(role: .user, content: text)
        messages.append(userMessage)
        partialTranscript = ""

        await thinkAndSpeak()
    }

    private func thinkAndSpeak() async {
        // Phase 1: Thinking — stream response from Claude
        conversationState = .thinking
        currentResponseText = ""

        var fullResponse = ""

        do {
            let stream = await claudeService.streamChat(messages: messages)
            for try await chunk in stream {
                guard !Task.isCancelled else { return }
                fullResponse += chunk
                currentResponseText = fullResponse
            }
        } catch {
            errorMessage = error.localizedDescription
            conversationState = .idle
            return
        }

        guard !Task.isCancelled, !fullResponse.isEmpty else {
            conversationState = .idle
            return
        }

        // Strip emotion tags from display text
        let displayText = fullResponse.replacingOccurrences(
            of: #"\[emotion:\w+\]"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        messages.append(ConversationMessage(role: .assistant, content: displayText))

        // Analyze emotion
        let emotion = SentimentAnalyzer.analyze(fullResponse)
        currentEmotion = emotion
        animationMixer.emotionEngine.setEmotion(emotion)

        // Phase 2: Speaking — TTS + lip sync
        conversationState = .speaking

        do {
            let result = try await azureService.synthesize(text: displayText)
            guard !Task.isCancelled else {
                conversationState = .idle
                return
            }

            // Load viseme data and start lip sync
            animationMixer.lipSyncEngine.load(result.visemeData)
            animationMixer.lipSyncEngine.play()

            // Play audio (suspends until playback completes)
            let format = audioManager.speechOutputFormat
            await audioManager.playAudioData(result.audioData, format: format)

            // Ensure lip sync also finishes
            await animationMixer.lipSyncEngine.waitForCompletion()

        } catch {
            errorMessage = error.localizedDescription
        }

        // Return to idle
        conversationState = .idle
        currentEmotion = .neutral
        animationMixer.emotionEngine.setEmotion(.neutral)
    }
}
