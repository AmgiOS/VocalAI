import Speech
import AVFoundation

/// Wraps Apple's SFSpeechRecognizer for on-device speech-to-text.
@MainActor
final class SpeechRecognitionService {
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    var onPartialResult: ((String) -> Void)?
    var onFinalResult: ((String) -> Void)?
    var onError: ((Error) -> Void)?

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

    // MARK: - Recognition Control

    /// Start speech recognition. Feed audio buffers via `appendBuffer(_:)`.
    func startRecognition() throws {
        stopRecognition()

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true

        // Prefer on-device recognition when available
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        recognitionRequest = request

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                if let result {
                    let text = result.bestTranscription.formattedString
                    if result.isFinal {
                        self?.onFinalResult?(text)
                        self?.stopRecognition()
                    } else {
                        self?.onPartialResult?(text)
                    }
                }

                if let error {
                    // Ignore cancellation errors from stopping recognition
                    if (error as NSError).code != 216 {
                        self?.onError?(error)
                    }
                }
            }
        }
    }

    /// Feed an audio buffer from AVAudioEngine to the recognizer.
    func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }

    /// Stop recognition and clean up.
    func stopRecognition() {
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
