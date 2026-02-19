import Foundation
import MicrosoftCognitiveServicesSpeech

/// Azure Speech SDK service for TTS with FacialExpression visemes.
/// Provides both audio data and 55 blend shape weights at ~60 FPS.
actor AzureSpeechService {
    private var synthesizer: SPXSpeechSynthesizer?
    private var speechConfig: SPXSpeechConfiguration?

    // MARK: - Setup

    func configure() throws {
        guard Configuration.isAzureConfigured else {
            throw AzureError.notConfigured
        }

        let config = try SPXSpeechConfiguration(
            subscription: Configuration.azureSpeechKey,
            region: Configuration.azureSpeechRegion
        )

        // Request raw PCM audio (16kHz, 16-bit, mono)
        config.setSpeechSynthesisOutputFormat(.raw16Khz16BitMonoPcm)

        speechConfig = config
    }

    // MARK: - TTS with Visemes

    /// Synthesize speech with SSML FacialExpression visemes.
    /// Returns audio data + viseme frames for lip sync.
    func synthesize(text: String, voiceName: String = Configuration.azureVoiceName) async throws -> SynthesisResult {
        guard let config = speechConfig else {
            throw AzureError.notConfigured
        }

        // Use pull audio stream to capture raw audio
        let audioStream = SPXPullAudioOutputStream()
        let audioConfig = try SPXAudioConfiguration(streamOutput: audioStream)

        let synth = try SPXSpeechSynthesizer(speechConfiguration: config, audioConfiguration: audioConfig)

        // Collect viseme frames
        var allFrames: [VisemeFrame] = []
        var frameOffset = 0

        synth.addVisemeReceivedEventHandler { _, event in
            let animation = event.animation
            guard !animation.isEmpty,
                  let data = animation.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(AzureVisemePayload.self, from: data) else {
                return
            }
            let frames = payload.toVisemeFrames(startingIndex: frameOffset)
            allFrames.append(contentsOf: frames)
            frameOffset += payload.BlendShapes.count
        }

        // Build SSML with FacialExpression viseme type
        let ssml = buildSSML(text: text, voiceName: voiceName)

        // Perform synthesis
        let result = try synth.speakSsml(ssml)

        guard result.reason == .synthesizingAudioCompleted else {
            if let details = result.properties?.getPropertyBy(.speechServiceResponseJsonResult) {
                throw AzureError.synthesisError(details)
            }
            throw AzureError.synthesisError("Synthesis failed with reason: \(result.reason.rawValue)")
        }

        // Read audio data from stream
        let audioData = readAudioStream(audioStream)

        return SynthesisResult(
            audioData: audioData,
            visemeData: VisemeData(frames: allFrames)
        )
    }

    // MARK: - SSML Builder

    private func buildSSML(text: String, voiceName: String) -> String {
        let escapedText = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        return """
        <speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" \
        xmlns:mstts="http://www.w3.org/2001/mstts" xml:lang="\(Configuration.speechLanguage)">
          <voice name="\(voiceName)">
            <mstts:viseme type="FacialExpression"/>
            \(escapedText)
          </voice>
        </speak>
        """
    }

    // MARK: - Audio Stream Reading

    private func readAudioStream(_ stream: SPXPullAudioOutputStream) -> Data {
        var audioData = Data()
        let chunkSize: UInt = 4096
        let buffer = NSMutableData(capacity: Int(chunkSize))!

        while stream.read(buffer, length: chunkSize) > 0 {
            audioData.append(buffer as Data)
            buffer.length = 0
        }

        return audioData
    }
}

// MARK: - Result Type

nonisolated struct SynthesisResult: Sendable {
    let audioData: Data
    let visemeData: VisemeData
}

// MARK: - Errors

nonisolated enum AzureError: LocalizedError {
    case notConfigured
    case synthesisError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Azure Speech is not configured. Add your key and region in Settings."
        case .synthesisError(let detail):
            return "Azure synthesis error: \(detail)"
        }
    }
}
