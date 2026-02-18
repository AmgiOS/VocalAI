import Foundation
import QuartzCore

/// Plays back Azure viseme frames synchronized with audio playback.
/// Uses CADisplayLink for frame-accurate timing.
@MainActor
final class LipSyncEngine {
    private var frames: [VisemeFrame] = []
    private var displayLink: CADisplayLink?
    private var audioStartTime: CFTimeInterval = 0
    private var currentFrameIndex: Int = 0

    var isPlaying = false
    private(set) var currentWeights: [BlendShapeTarget: Float] = [:]

    var onComplete: (() -> Void)?

    // MARK: - Playback Control

    /// Load viseme frames and prepare for playback.
    func load(_ visemeData: VisemeData) {
        frames = visemeData.frames
        currentFrameIndex = 0
        currentWeights = [:]
    }

    /// Start lip sync playback. Call this at the exact moment audio playback begins.
    func play() {
        guard !frames.isEmpty else { return }
        isPlaying = true
        audioStartTime = CACurrentMediaTime()
        currentFrameIndex = 0

        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60)
        displayLink?.add(to: .main, forMode: .common)
    }

    /// Stop lip sync playback.
    func stop() {
        isPlaying = false
        displayLink?.invalidate()
        displayLink = nil
        currentWeights = [:]
        frames = []
    }

    // MARK: - Frame Update

    @objc private func update(_ link: CADisplayLink) {
        guard isPlaying, !frames.isEmpty else { return }

        let elapsed = link.timestamp - audioStartTime
        let targetTime = elapsed

        // Find the two frames surrounding the current time for interpolation
        while currentFrameIndex < frames.count - 1 &&
              frames[currentFrameIndex + 1].timeOffset <= targetTime {
            currentFrameIndex += 1
        }

        // Check if we've reached the end
        if currentFrameIndex >= frames.count - 1 {
            if let lastFrame = frames.last {
                currentWeights = lastFrame.blendShapes
            }
            completePlayback()
            return
        }

        // Interpolate between current and next frame
        let current = frames[currentFrameIndex]
        let next = frames[currentFrameIndex + 1]
        let frameDuration = next.timeOffset - current.timeOffset

        if frameDuration > 0 {
            let t = Float((targetTime - current.timeOffset) / frameDuration)
            let clampedT = max(0, min(1, t))
            currentWeights = lerpWeights(current.blendShapes, next.blendShapes, t: clampedT)
        } else {
            currentWeights = current.blendShapes
        }
    }

    // MARK: - Private

    private func completePlayback() {
        isPlaying = false
        displayLink?.invalidate()
        displayLink = nil

        // Fade out mouth shapes
        currentWeights = [:]
        onComplete?()
    }
}
