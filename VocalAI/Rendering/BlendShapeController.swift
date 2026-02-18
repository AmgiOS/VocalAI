import RealityKit

/// Controls blend shape weights on a RealityKit entity via BlendShapeWeightsComponent.
@MainActor
final class BlendShapeController {
    private let rootEntity: Entity
    private var meshEntity: ModelEntity?
    private var weightsMapping: BlendShapeWeightsMapping?
    private var currentWeights: [BlendShapeTarget: Float] = [:]

    init(entity: Entity) {
        self.rootEntity = entity
        findMeshEntity()
    }

    // MARK: - Setup

    private func findMeshEntity() {
        if let model = rootEntity as? ModelEntity, model.components.has(BlendShapeWeightsComponent.self) {
            meshEntity = model
        } else {
            meshEntity = findFirstEntityWithBlendShapes(in: rootEntity)
        }

        guard let meshEntity else { return }

        if let component = meshEntity.components[BlendShapeWeightsComponent.self] {
            weightsMapping = component.weightsMapping
        }
    }

    private func findFirstEntityWithBlendShapes(in entity: Entity) -> ModelEntity? {
        if let model = entity as? ModelEntity, model.components.has(BlendShapeWeightsComponent.self) {
            return model
        }
        for child in entity.children {
            if let found = findFirstEntityWithBlendShapes(in: child) {
                return found
            }
        }
        return nil
    }

    // MARK: - Weight Control

    /// Set a single blend shape weight (0.0 to 1.0).
    func setWeight(_ target: BlendShapeTarget, value: Float) {
        currentWeights[target] = value
        applyWeight(target, value: value)
    }

    /// Set multiple blend shape weights at once.
    func setWeights(_ weights: [BlendShapeTarget: Float]) {
        for (target, value) in weights {
            currentWeights[target] = value
        }
        applyAllWeights()
    }

    /// Apply a complete frame of blend shape weights, resetting any not specified to 0.
    func applyFrame(_ weights: [BlendShapeTarget: Float]) {
        currentWeights = weights
        applyAllWeights()
    }

    /// Get the current weight for a blend shape target.
    func getWeight(_ target: BlendShapeTarget) -> Float {
        currentWeights[target] ?? 0
    }

    /// Reset all blend shapes to 0.
    func resetAll() {
        currentWeights.removeAll()
        applyAllWeights()
    }

    /// Whether the entity has working blend shapes.
    var hasBlendShapes: Bool {
        weightsMapping != nil && meshEntity != nil
    }

    // MARK: - Private

    private func applyWeight(_ target: BlendShapeTarget, value: Float) {
        guard let meshEntity, var component = meshEntity.components[BlendShapeWeightsComponent.self],
              let mapping = weightsMapping else { return }

        let clamped = max(0, min(1, value))

        do {
            let indices = mapping.indices(of: target.rawValue)
            for index in indices {
                component.weights[index] = clamped
            }
            meshEntity.components.set(component)
        }
    }

    private func applyAllWeights() {
        guard let meshEntity, var component = meshEntity.components[BlendShapeWeightsComponent.self],
              let mapping = weightsMapping else { return }

        // Reset all to 0 first
        for i in 0..<component.weights.count {
            component.weights[i] = 0
        }

        // Apply current weights
        for (target, value) in currentWeights {
            let clamped = max(0, min(1, value))
            let indices = mapping.indices(of: target.rawValue)
            for index in indices {
                component.weights[index] = clamped
            }
        }

        meshEntity.components.set(component)
    }
}
