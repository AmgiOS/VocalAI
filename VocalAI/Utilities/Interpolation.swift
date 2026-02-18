import Foundation

// MARK: - Interpolation Functions

/// Linear interpolation between two values.
func lerp(_ a: Float, _ b: Float, t: Float) -> Float {
    a + (b - a) * t
}

/// Hermite smoothstep interpolation (smooth ease-in/ease-out).
func smoothstep(_ edge0: Float, _ edge1: Float, x: Float) -> Float {
    let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)
}

/// Smoother step (Ken Perlin's improved version).
func smootherstep(_ edge0: Float, _ edge1: Float, x: Float) -> Float {
    let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
    return t * t * t * (t * (t * 6 - 15) + 10)
}

/// Interpolate a dictionary of blend shape weights.
func lerpWeights(
    _ from: [BlendShapeTarget: Float],
    _ to: [BlendShapeTarget: Float],
    t: Float
) -> [BlendShapeTarget: Float] {
    var result: [BlendShapeTarget: Float] = [:]
    let allKeys = Set(from.keys).union(to.keys)

    for key in allKeys {
        let fromValue = from[key] ?? 0
        let toValue = to[key] ?? 0
        let interpolated = lerp(fromValue, toValue, t: t)
        if abs(interpolated) > 0.001 {
            result[key] = interpolated
        }
    }

    return result
}

/// Interpolate a dictionary of blend shape weights using smoothstep.
func smoothLerpWeights(
    _ from: [BlendShapeTarget: Float],
    _ to: [BlendShapeTarget: Float],
    t: Float
) -> [BlendShapeTarget: Float] {
    let smoothT = smoothstep(0, 1, x: t)
    return lerpWeights(from, to, t: smoothT)
}
