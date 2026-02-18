import Foundation
import QuartzCore

/// Manages emotion state with smooth transitions between presets.
@MainActor
final class EmotionEngine {
    private var currentEmotion: EmotionType = .neutral
    private var targetEmotion: EmotionType = .neutral
    private var previousWeights: [BlendShapeTarget: Float] = [:]
    private var transitionStart: CFTimeInterval = 0
    private var transitionDuration: Double = Configuration.emotionTransitionDuration
    private var isTransitioning = false

    private(set) var currentWeights: [BlendShapeTarget: Float] = [:]

    // MARK: - Emotion Control

    func setEmotion(_ emotion: EmotionType) {
        guard emotion != targetEmotion else { return }
        previousWeights = currentWeights
        targetEmotion = emotion
        transitionStart = CACurrentMediaTime()
        isTransitioning = true
    }

    /// Call each frame to update the current weights during a transition.
    func update() {
        guard isTransitioning else { return }

        let now = CACurrentMediaTime()
        let elapsed = now - transitionStart
        let t = Float(min(1.0, elapsed / transitionDuration))

        currentWeights = smoothLerpWeights(
            previousWeights,
            targetEmotion.blendShapePreset,
            t: t
        )

        if t >= 1.0 {
            isTransitioning = false
            currentEmotion = targetEmotion
            currentWeights = targetEmotion.blendShapePreset
        }
    }

    /// Reset to neutral emotion immediately.
    func reset() {
        currentEmotion = .neutral
        targetEmotion = .neutral
        currentWeights = [:]
        isTransitioning = false
    }
}
