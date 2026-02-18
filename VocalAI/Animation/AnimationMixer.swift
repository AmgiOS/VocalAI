import Foundation
import QuartzCore

/// Combines lip sync, emotion, and idle animations with priority-based blending.
/// Priority: lip sync (mouth) > emotion (brows, expressions) > idle (background).
@MainActor
final class AnimationMixer {
    let lipSyncEngine = LipSyncEngine()
    let emotionEngine = EmotionEngine()
    let idleAnimator = IdleAnimator()

    private var displayLink: CADisplayLink?
    private var blendShapeController: BlendShapeController?

    var isActive = false

    // MARK: - Setup

    func attach(to controller: BlendShapeController) {
        blendShapeController = controller
    }

    // MARK: - Lifecycle

    func start() {
        guard !isActive else { return }
        isActive = true
        idleAnimator.start()

        displayLink = CADisplayLink(target: self, selector: #selector(mixAndApply))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60)
        displayLink?.add(to: .main, forMode: .common)
    }

    func stop() {
        isActive = false
        displayLink?.invalidate()
        displayLink = nil
        idleAnimator.stop()
        lipSyncEngine.stop()
        blendShapeController?.resetAll()
    }

    // MARK: - Mixing

    @objc private func mixAndApply(_ link: CADisplayLink) {
        emotionEngine.update()

        var finalWeights: [BlendShapeTarget: Float] = [:]

        // Layer 1: Idle (lowest priority, full coverage)
        let idleWeights = idleAnimator.currentWeights
        for (target, value) in idleWeights {
            finalWeights[target] = value
        }

        // Layer 2: Emotion (overrides brows + cheeks, blends with idle eyes)
        let emotionWeights = emotionEngine.currentWeights
        for (target, value) in emotionWeights {
            if BlendShapeTarget.browShapes.contains(target) {
                // Emotion fully owns brow shapes
                finalWeights[target] = value
            } else if BlendShapeTarget.eyeShapes.contains(target) {
                // Blend emotion eyes with idle eyes (additive, clamped)
                let existing = finalWeights[target] ?? 0
                finalWeights[target] = min(1.0, existing + value)
            } else if !BlendShapeTarget.mouthShapes.contains(target) {
                // Non-mouth, non-brow, non-eye: emotion takes precedence
                finalWeights[target] = value
            } else if !lipSyncEngine.isPlaying {
                // Mouth shapes from emotion only when not lip syncing
                finalWeights[target] = value
            }
        }

        // Layer 3: Lip sync (highest priority for mouth shapes)
        if lipSyncEngine.isPlaying {
            let lipWeights = lipSyncEngine.currentWeights
            for (target, value) in lipWeights {
                if BlendShapeTarget.mouthShapes.contains(target) {
                    // Lip sync fully owns mouth during speech
                    finalWeights[target] = value
                } else {
                    // Non-mouth shapes from Azure (eye gaze, brow movement during speech)
                    // Blend additively with existing
                    let existing = finalWeights[target] ?? 0
                    finalWeights[target] = min(1.0, existing * 0.5 + value * 0.5)
                }
            }
        }

        blendShapeController?.applyFrame(finalWeights)
    }
}
