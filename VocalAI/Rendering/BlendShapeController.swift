import RealityKit

/// Controls blend shape weights on a RealityKit entity via BlendShapeWeightsComponent.
@MainActor
final class BlendShapeController {
    private let rootEntity: Entity
    private var meshEntity: ModelEntity?
    private var currentWeights: [BlendShapeTarget: Float] = [:]

    init(entity: Entity) {
        self.rootEntity = entity
        findMeshEntity()
    }

    // MARK: - Setup

    private func findMeshEntity() {
        if let model = rootEntity as? ModelEntity,
           model.components.has(BlendShapeWeightsComponent.self) {
            meshEntity = model
        } else {
            meshEntity = findFirstModelEntity(in: rootEntity)
        }

        guard let meshEntity else { return }

        // Create BlendShapeWeightsComponent from mesh if not already present
        if meshEntity.components[BlendShapeWeightsComponent.self] == nil,
           let modelComponent = meshEntity.components[ModelComponent.self] {
            let mapping = BlendShapeWeightsMapping(meshResource: modelComponent.mesh)
            meshEntity.components.set(BlendShapeWeightsComponent(weightsMapping: mapping))
        }
    }

    private func findFirstModelEntity(in entity: Entity) -> ModelEntity? {
        if let model = entity as? ModelEntity,
           model.components.has(ModelComponent.self) {
            return model
        }
        for child in entity.children {
            if let found = findFirstModelEntity(in: child) {
                return found
            }
        }
        return nil
    }

    // MARK: - Weight Control

    /// Set a single blend shape weight (0.0 to 1.0).
    func setWeight(_ target: BlendShapeTarget, value: Float) {
        currentWeights[target] = value
        applyAllWeights()
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
        guard let meshEntity,
              let component = meshEntity.components[BlendShapeWeightsComponent.self],
              component.weightSet.default != nil else {
            return false
        }
        return true
    }

    // MARK: - Private

    private func applyAllWeights() {
        guard let meshEntity,
              var component = meshEntity.components[BlendShapeWeightsComponent.self] else { return }

        var weightSet = component.weightSet
        guard var blendData = weightSet.default else { return }

        // Reset all weights to 0
        for i in blendData.weights.indices {
            blendData.weights[i] = 0
        }

        // Apply current weights by matching name
        for (target, value) in currentWeights {
            let clamped = max(0, min(1, value))
            if let index = blendData.weightNames.firstIndex(of: target.rawValue) {
                blendData.weights[index] = clamped
            }
        }

        // Write back through the full chain
        weightSet.set(blendData)
        component.weightSet = weightSet
        meshEntity.components.set(component)
    }
}
