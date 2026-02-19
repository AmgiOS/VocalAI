import Foundation

/// A single frame of Azure Speech SDK FacialExpression viseme data.
/// Each frame contains 55 blend shape weights at ~60 FPS.
nonisolated struct VisemeFrame: Sendable {
    let frameIndex: Int
    let blendShapes: [BlendShapeTarget: Float]

    /// Time offset from the start of the audio (in seconds).
    var timeOffset: Double {
        Double(frameIndex) / Configuration.lipSyncFrameRate
    }
}

/// Container for all viseme frames from a single TTS utterance.
nonisolated struct VisemeData: Sendable {
    let frames: [VisemeFrame]
    let totalDuration: Double

    init(frames: [VisemeFrame]) {
        self.frames = frames
        self.totalDuration = frames.last?.timeOffset ?? 0
    }
}

// MARK: - Azure JSON Parsing

/// Raw JSON structure from Azure VisemeReceived event:
/// { "FrameIndex": 0, "BlendShapes": [[0.0, 0.1, ...], [0.0, 0.2, ...], ...] }
nonisolated struct AzureVisemePayload: Decodable, Sendable {
    let FrameIndex: Int
    let BlendShapes: [[Float]]

    func toVisemeFrames(startingIndex: Int = 0) -> [VisemeFrame] {
        BlendShapes.enumerated().map { offset, weights in
            VisemeFrame(
                frameIndex: startingIndex + offset,
                blendShapes: BlendShapeTarget.fromAzureArray(weights)
            )
        }
    }
}
