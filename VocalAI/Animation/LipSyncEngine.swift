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
    private var completionContinuation: CheckedContinuation<Void, Never>?

    var isPlaying = false
    private(set) var currentWeights: [BlendShapeTarget: Float] = [:]

    // MARK: - Playback Control

    /// Load viseme frames and prepare for playback.
    func load(_ visemeData: VisemeData) {
        frames = visemeData.frames
        currentFrameIndex = 0
        currentWeights = [:]
    }

    /// Start lip sync playback and suspend until complete.
    func playAndWait() async {
        guard !frames.isEmpty else { return }

        isPlaying = true
        audioStartTime = CACurrentMediaTime()
        currentFrameIndex = 0

        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60)
        displayLink?.add(to: .main, forMode: .common)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.completionContinuation = continuation
        }
    }

    /// Start lip sync playback (fire-and-forget for concurrent use with audio).
    func play() {
        guard !frames.isEmpty else { return }

        isPlaying = true
        audioStartTime = CACurrentMediaTime()
        currentFrameIndex = 0

        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60)
        displayLink?.add(to: .main, forMode: .common)
    }

    /// Wait for the current lip sync playback to finish.
    func waitForCompletion() async {
        guard isPlaying else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.completionContinuation = continuation
        }
    }

    /// Stop lip sync playback immediately.
    func stop() {
        isPlaying = false
        displayLink?.invalidate()
        displayLink = nil
        currentWeights = [:]
        frames = []
        completionContinuation?.resume()
        completionContinuation = nil
    }

    // MARK: - Frame Update

    @objc private func update(_ link: CADisplayLink) {
        guard isPlaying, !frames.isEmpty else { return }

        let elapsed = link.timestamp - audioStartTime

        // Advance to the correct frame
        while currentFrameIndex < frames.count - 1 &&
              frames[currentFrameIndex + 1].timeOffset <= elapsed {
            currentFrameIndex += 1
        }

        // End of frames
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
            let t = Float((elapsed - current.timeOffset) / frameDuration)
            currentWeights = lerpWeights(current.blendShapes, next.blendShapes, t: max(0, min(1, t)))
        } else {
            currentWeights = current.blendShapes
        }
    }

    // MARK: - Private

    private func completePlayback() {
        isPlaying = false
        displayLink?.invalidate()
        displayLink = nil
        currentWeights = [:]
        completionContinuation?.resume()
        completionContinuation = nil
    }
}
