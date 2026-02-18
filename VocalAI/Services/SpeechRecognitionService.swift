import Speech
import AVFoundation

/// Result emitted by the speech recognition stream.
enum SpeechResult: Sendable {
    case partial(String)
    case final(String)
}

/// Wraps Apple's SFSpeechRecognizer for on-device speech-to-text.
/// Results are delivered via an `AsyncStream<SpeechResult>`.
@MainActor
final class SpeechRecognitionService {
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var resultContinuation: AsyncStream<SpeechResult>.Continuation?

    var isRecognizing: Bool { recognitionTask != nil }

    init(locale: Locale = Locale(identifier: Configuration.speechLanguage)) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    // MARK: - Authorization

    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: - Recognition

    /// Start speech recognition and return a stream of results.
    /// Feed audio buffers via `appendBuffer(_:)`. Call `stopRecognition()` to end.
    func startRecognition() throws -> AsyncStream<SpeechResult> {
        stopRecognition()

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true

        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        recognitionRequest = request

        let stream = AsyncStream<SpeechResult> { continuation in
            self.resultContinuation = continuation

            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.cleanupRecognition()
                }
            }
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let result {
                    let text = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.resultContinuation?.yield(.final(text))
                        self.resultContinuation?.finish()
                        self.cleanupRecognition()
                    } else {
                        self.resultContinuation?.yield(.partial(text))
                    }
                }

                if let error, (error as NSError).code != 216 {
                    self.resultContinuation?.finish()
                    self.cleanupRecognition()
                }
            }
        }

        return stream
    }

    /// Feed an audio buffer from AVAudioEngine to the recognizer.
    func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }

    /// Stop recognition and finish the stream.
    func stopRecognition() {
        resultContinuation?.finish()
        resultContinuation = nil
        cleanupRecognition()
    }

    private func cleanupRecognition() {
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}

// MARK: - Errors

enum SpeechError: LocalizedError {
    case recognizerUnavailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognizer is not available for the current language."
        case .notAuthorized:
            return "Speech recognition is not authorized. Enable it in Settings."
        }
    }
}
