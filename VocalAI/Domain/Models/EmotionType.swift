import Foundation

nonisolated enum EmotionType: String, CaseIterable, Sendable {
    case neutral
    case happy
    case sad
    case surprised
    case angry
    case thinking
    case empathetic

    /// Blend shape preset for this emotion.
    /// Values are target weights that get blended with the current state.
    var blendShapePreset: [BlendShapeTarget: Float] {
        switch self {
        case .neutral:
            return [:]

        case .happy:
            return [
                .mouthSmileLeft: 0.6,
                .mouthSmileRight: 0.6,
                .cheekSquintLeft: 0.3,
                .cheekSquintRight: 0.3,
                .eyeSquintLeft: 0.15,
                .eyeSquintRight: 0.15,
                .browInnerUp: 0.1
            ]

        case .sad:
            return [
                .mouthFrownLeft: 0.5,
                .mouthFrownRight: 0.5,
                .browInnerUp: 0.4,
                .browDownLeft: 0.2,
                .browDownRight: 0.2,
                .eyeLookDownLeft: 0.15,
                .eyeLookDownRight: 0.15
            ]

        case .surprised:
            return [
                .eyeWideLeft: 0.7,
                .eyeWideRight: 0.7,
                .browOuterUpLeft: 0.5,
                .browOuterUpRight: 0.5,
                .browInnerUp: 0.6,
                .jawOpen: 0.3,
                .mouthFunnel: 0.2
            ]

        case .angry:
            return [
                .browDownLeft: 0.6,
                .browDownRight: 0.6,
                .eyeSquintLeft: 0.3,
                .eyeSquintRight: 0.3,
                .mouthPressLeft: 0.4,
                .mouthPressRight: 0.4,
                .jawForward: 0.15,
                .noseSneerLeft: 0.3,
                .noseSneerRight: 0.3
            ]

        case .thinking:
            return [
                .browInnerUp: 0.2,
                .browOuterUpLeft: 0.15,
                .eyeLookUpLeft: 0.2,
                .eyeLookUpRight: 0.15,
                .mouthPucker: 0.15,
                .mouthRight: 0.1
            ]

        case .empathetic:
            return [
                .browInnerUp: 0.35,
                .mouthSmileLeft: 0.2,
                .mouthSmileRight: 0.2,
                .eyeSquintLeft: 0.1,
                .eyeSquintRight: 0.1,
                .mouthFrownLeft: 0.1,
                .mouthFrownRight: 0.1
            ]
        }
    }
}
