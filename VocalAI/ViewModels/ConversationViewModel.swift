import Foundation
import AVFoundation
import Observation

/// Orchestrates the full conversation pipeline:
/// listening → thinking → speaking → idle
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

    // MARK: - Init

    init() {
        speechService = SpeechRecognitionService()
        setupSpeechCallbacks()
    }

    // MARK: - Lifecycle

    func setup() async {
        // Configure Azure
        do {
            try await azureService.configure()
        } catch {
            errorMessage = error.localizedDescription
        }

        // Start audio engine
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
            try speechService.startRecognition()
            audioManager.startMicCapture()
            audioManager.onMicBuffer = { [weak self] buffer, _ in
                self?.speechService.appendBuffer(buffer)
            }
        } catch {
            errorMessage = error.localizedDescription
            conversationState = .idle
        }
    }

    /// Stop listening and process the captured speech.
    func stopListening() {
        guard conversationState == .listening else { return }
        audioManager.stopMicCapture()
        speechService.stopRecognition()

        let transcript = partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            conversationState = .idle
            return
        }

        processUserMessage(transcript)
    }

    /// Cancel any ongoing processing and return to idle.
    func stopConversation() {
        currentTask?.cancel()
        currentTask = nil
        audioManager.stopPlayback()
        audioManager.stopMicCapture()
        speechService.stopRecognition()
        animationMixer.lipSyncEngine.stop()
        conversationState = .idle
        currentEmotion = .neutral
        animationMixer.emotionEngine.reset()
    }

    // MARK: - Pipeline

    private func processUserMessage(_ text: String) {
        let userMessage = ConversationMessage(role: .user, content: text)
        messages.append(userMessage)
        partialTranscript = ""

        currentTask = Task {
            await thinkAndSpeak()
        }
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

        let assistantMessage = ConversationMessage(role: .assistant, content: displayText)
        messages.append(assistantMessage)

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

            // Load viseme data into lip sync engine
            animationMixer.lipSyncEngine.load(result.visemeData)

            // Play audio and start lip sync simultaneously
            let format = audioManager.speechOutputFormat
            animationMixer.lipSyncEngine.play()
            audioManager.playAudioData(result.audioData, format: format)

            // Wait for playback to complete
            await waitForPlaybackCompletion()

        } catch {
            errorMessage = error.localizedDescription
        }

        // Return to idle
        conversationState = .idle
        currentEmotion = .neutral
        animationMixer.emotionEngine.setEmotion(.neutral)
    }

    private func waitForPlaybackCompletion() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            audioManager.onPlaybackComplete = {
                continuation.resume()
            }
            animationMixer.lipSyncEngine.onComplete = { [weak self] in
                if self?.audioManager.isPlaying == false {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Speech Callbacks

    private func setupSpeechCallbacks() {
        speechService.onPartialResult = { [weak self] text in
            self?.partialTranscript = text
        }

        speechService.onFinalResult = { [weak self] text in
            guard let self else { return }
            self.partialTranscript = text
            if self.conversationState == .listening {
                self.stopListening()
            }
        }

        speechService.onError = { [weak self] error in
            self?.errorMessage = error.localizedDescription
        }
    }
}
