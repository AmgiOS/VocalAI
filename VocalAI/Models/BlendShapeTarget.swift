import Foundation

/// All 52 ARKit blend shapes supported by Character Creator 5 exports.
/// The order matches Azure Speech SDK's FacialExpression viseme output (indices 0-51),
/// plus 3 Azure-only extras (headRoll, leftEyeRoll, rightEyeRoll at indices 52-54).
enum BlendShapeTarget: String, CaseIterable, Sendable {
    // MARK: - Eye (Brow)
    case browDownLeft
    case browDownRight
    case browInnerUp
    case browOuterUpLeft
    case browOuterUpRight

    // MARK: - Eye
    case eyeBlinkLeft
    case eyeBlinkRight
    case eyeLookDownLeft
    case eyeLookDownRight
    case eyeLookInLeft
    case eyeLookInRight
    case eyeLookOutLeft
    case eyeLookOutRight
    case eyeLookUpLeft
    case eyeLookUpRight
    case eyeSquintLeft
    case eyeSquintRight
    case eyeWideLeft
    case eyeWideRight

    // MARK: - Jaw
    case jawForward
    case jawLeft
    case jawOpen
    case jawRight

    // MARK: - Mouth
    case mouthClose
    case mouthDimpleLeft
    case mouthDimpleRight
    case mouthFrownLeft
    case mouthFrownRight
    case mouthFunnel
    case mouthLeft
    case mouthLowerDownLeft
    case mouthLowerDownRight
    case mouthPressLeft
    case mouthPressRight
    case mouthPucker
    case mouthRight
    case mouthRollLower
    case mouthRollUpper
    case mouthShrugLower
    case mouthShrugUpper
    case mouthSmileLeft
    case mouthSmileRight
    case mouthStretchLeft
    case mouthStretchRight
    case mouthUpperUpLeft
    case mouthUpperUpRight

    // MARK: - Nose
    case noseSneerLeft
    case noseSneerRight

    // MARK: - Cheek
    case cheekPuff
    case cheekSquintLeft
    case cheekSquintRight

    // MARK: - Tongue
    case tongueOut

    // MARK: - Mouth region shapes (for AnimationMixer priority)

    static let mouthShapes: Set<BlendShapeTarget> = [
        .jawForward, .jawLeft, .jawOpen, .jawRight,
        .mouthClose, .mouthDimpleLeft, .mouthDimpleRight,
        .mouthFrownLeft, .mouthFrownRight, .mouthFunnel,
        .mouthLeft, .mouthLowerDownLeft, .mouthLowerDownRight,
        .mouthPressLeft, .mouthPressRight, .mouthPucker,
        .mouthRight, .mouthRollLower, .mouthRollUpper,
        .mouthShrugLower, .mouthShrugUpper, .mouthSmileLeft,
        .mouthSmileRight, .mouthStretchLeft, .mouthStretchRight,
        .mouthUpperUpLeft, .mouthUpperUpRight, .tongueOut
    ]

    static let browShapes: Set<BlendShapeTarget> = [
        .browDownLeft, .browDownRight, .browInnerUp,
        .browOuterUpLeft, .browOuterUpRight
    ]

    static let eyeShapes: Set<BlendShapeTarget> = [
        .eyeBlinkLeft, .eyeBlinkRight,
        .eyeLookDownLeft, .eyeLookDownRight,
        .eyeLookInLeft, .eyeLookInRight,
        .eyeLookOutLeft, .eyeLookOutRight,
        .eyeLookUpLeft, .eyeLookUpRight,
        .eyeSquintLeft, .eyeSquintRight,
        .eyeWideLeft, .eyeWideRight
    ]
}

// MARK: - Azure Index Mapping

extension BlendShapeTarget {
    /// Azure Speech SDK FacialExpression viseme order (0-51 = ARKit, 52-54 = extras)
    static let azureOrder: [BlendShapeTarget] = [
        .browDownLeft, .browDownRight, .browInnerUp, .browOuterUpLeft, .browOuterUpRight,
        .cheekPuff, .cheekSquintLeft, .cheekSquintRight,
        .eyeBlinkLeft, .eyeBlinkRight,
        .eyeLookDownLeft, .eyeLookDownRight,
        .eyeLookInLeft, .eyeLookInRight,
        .eyeLookOutLeft, .eyeLookOutRight,
        .eyeLookUpLeft, .eyeLookUpRight,
        .eyeSquintLeft, .eyeSquintRight, .eyeWideLeft, .eyeWideRight,
        .jawForward, .jawLeft, .jawOpen, .jawRight,
        .mouthClose, .mouthDimpleLeft, .mouthDimpleRight,
        .mouthFrownLeft, .mouthFrownRight, .mouthFunnel,
        .mouthLeft, .mouthLowerDownLeft, .mouthLowerDownRight,
        .mouthPressLeft, .mouthPressRight, .mouthPucker,
        .mouthRight, .mouthRollLower, .mouthRollUpper,
        .mouthShrugLower, .mouthShrugUpper,
        .mouthSmileLeft, .mouthSmileRight,
        .mouthStretchLeft, .mouthStretchRight,
        .mouthUpperUpLeft, .mouthUpperUpRight,
        .noseSneerLeft, .noseSneerRight,
        .tongueOut
    ]

    /// Convert a flat array of 55 Azure blend shape values to a dictionary keyed by BlendShapeTarget.
    /// Indices 52-54 (headRoll, leftEyeRoll, rightEyeRoll) are ignored.
    static func fromAzureArray(_ values: [Float]) -> [BlendShapeTarget: Float] {
        var result: [BlendShapeTarget: Float] = [:]
        let count = min(values.count, azureOrder.count)
        for i in 0..<count {
            result[azureOrder[i]] = values[i]
        }
        return result
    }
}
