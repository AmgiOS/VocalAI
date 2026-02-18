import Foundation
import UIKit
import QuartzCore

/// Generates idle animations: breathing, blinking, and micro eye movements.
/// Respects `accessibilityReduceMotion`.
@MainActor
final class IdleAnimator {
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var nextBlinkTime: CFTimeInterval = 0
    private var blinkPhase: BlinkPhase = .idle
    private var blinkStartTime: CFTimeInterval = 0
    private var microMovementTarget: (x: Float, y: Float) = (0, 0)
    private var microMovementCurrent: (x: Float, y: Float) = (0, 0)
    private var nextMicroMovementTime: CFTimeInterval = 0

    var isActive = false
    private(set) var currentWeights: [BlendShapeTarget: Float] = [:]

    private enum BlinkPhase {
        case idle
        case closing
        case opening
    }

    // MARK: - Lifecycle

    func start() {
        guard !isActive else { return }
        isActive = true
        startTime = CACurrentMediaTime()
        nextBlinkTime = startTime + randomBlinkInterval()
        nextMicroMovementTime = startTime + Double.random(in: 1.5...3.0)

        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60)
        displayLink?.add(to: .main, forMode: .common)
    }

    func stop() {
        isActive = false
        displayLink?.invalidate()
        displayLink = nil
        currentWeights = [:]
    }

    // MARK: - Update

    @objc private func update(_ link: CADisplayLink) {
        let now = link.timestamp
        var weights: [BlendShapeTarget: Float] = [:]

        let reduceMotion = UIAccessibility.isReduceMotionEnabled

        // Breathing (sinusoidal, 4-second cycle)
        if !reduceMotion {
            let breathingT = Float(sin(2.0 * .pi * (now - startTime) / Configuration.breathingCycleDuration))
            let breathAmount = (breathingT + 1.0) / 2.0 * 0.05 // 0 to 0.05
            weights[.jawOpen] = breathAmount * 0.3
            weights[.mouthClose] = breathAmount * 0.1
            weights[.noseSneerLeft] = breathAmount * 0.02
            weights[.noseSneerRight] = breathAmount * 0.02
        }

        // Blinking
        updateBlink(now: now, weights: &weights)

        // Micro eye movements
        if !reduceMotion {
            updateMicroMovements(now: now, weights: &weights)
        }

        currentWeights = weights
    }

    // MARK: - Blinking

    private func updateBlink(now: CFTimeInterval, weights: inout [BlendShapeTarget: Float]) {
        let blinkDuration = Configuration.blinkDuration

        switch blinkPhase {
        case .idle:
            if now >= nextBlinkTime {
                blinkPhase = .closing
                blinkStartTime = now
            }

        case .closing:
            let elapsed = Float(now - blinkStartTime)
            let halfDuration = Float(blinkDuration / 2)
            let t = min(1.0, elapsed / halfDuration)
            let value = smoothstep(0, 1, x: t)
            weights[.eyeBlinkLeft] = value
            weights[.eyeBlinkRight] = value

            if t >= 1.0 {
                blinkPhase = .opening
            }

        case .opening:
            let elapsed = Float(now - blinkStartTime) - Float(blinkDuration / 2)
            let halfDuration = Float(blinkDuration / 2)
            let t = min(1.0, elapsed / halfDuration)
            let value = 1.0 - smoothstep(0, 1, x: t)
            weights[.eyeBlinkLeft] = value
            weights[.eyeBlinkRight] = value

            if t >= 1.0 {
                blinkPhase = .idle
                nextBlinkTime = now + randomBlinkInterval()
                // 15% chance of double blink
                if Float.random(in: 0...1) < 0.15 {
                    nextBlinkTime = now + 0.15
                }
            }
        }
    }

    // MARK: - Micro Eye Movements

    private func updateMicroMovements(now: CFTimeInterval, weights: inout [BlendShapeTarget: Float]) {
        if now >= nextMicroMovementTime {
            microMovementTarget = (
                x: Float.random(in: -0.03...0.03),
                y: Float.random(in: -0.02...0.02)
            )
            nextMicroMovementTime = now + Double.random(in: 1.5...3.5)
        }

        // Smooth towards target
        let speed: Float = 0.05
        microMovementCurrent.x = lerp(microMovementCurrent.x, microMovementTarget.x, t: speed)
        microMovementCurrent.y = lerp(microMovementCurrent.y, microMovementTarget.y, t: speed)

        if microMovementCurrent.x > 0 {
            weights[.eyeLookOutLeft] = (weights[.eyeLookOutLeft] ?? 0) + microMovementCurrent.x
            weights[.eyeLookInRight] = (weights[.eyeLookInRight] ?? 0) + microMovementCurrent.x
        } else {
            weights[.eyeLookInLeft] = (weights[.eyeLookInLeft] ?? 0) + abs(microMovementCurrent.x)
            weights[.eyeLookOutRight] = (weights[.eyeLookOutRight] ?? 0) + abs(microMovementCurrent.x)
        }

        if microMovementCurrent.y > 0 {
            weights[.eyeLookUpLeft] = (weights[.eyeLookUpLeft] ?? 0) + microMovementCurrent.y
            weights[.eyeLookUpRight] = (weights[.eyeLookUpRight] ?? 0) + microMovementCurrent.y
        } else {
            weights[.eyeLookDownLeft] = (weights[.eyeLookDownLeft] ?? 0) + abs(microMovementCurrent.y)
            weights[.eyeLookDownRight] = (weights[.eyeLookDownRight] ?? 0) + abs(microMovementCurrent.y)
        }
    }

    // MARK: - Helpers

    private func randomBlinkInterval() -> Double {
        Double.random(in: Configuration.blinkIntervalRange)
    }
}
