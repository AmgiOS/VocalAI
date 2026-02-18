import RealityKit
import UIKit

/// Manages the RealityKit scene: loading the USDZ avatar, configuring lighting, and camera.
@MainActor
final class AvatarRenderer {
    let arView: ARView
    private let anchor: AnchorEntity
    private(set) var avatarEntity: Entity?
    private(set) var blendShapeController: BlendShapeController?

    init() {
        arView = ARView(frame: .zero)
        arView.environment.background = .color(.black)
        arView.cameraMode = .nonAR
        arView.renderOptions = [.disableMotionBlur]

        anchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(anchor)

        configureCamera()
        configureLighting()
    }

    // MARK: - Avatar Loading

    func loadAvatar() async throws {
        let entity: Entity
        if let bundleURL = Bundle.main.url(forResource: Configuration.avatarAssetName, withExtension: "usdz") {
            entity = try await Entity(contentsOf: bundleURL)
        } else {
            entity = try await loadPlaceholder()
        }

        avatarEntity = entity
        anchor.addChild(entity)

        positionAvatar(entity)

        blendShapeController = BlendShapeController(entity: entity)
    }

    // MARK: - Camera

    private func configureCamera() {
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 30
        camera.position = [0, 1.5, 0.8]
        camera.look(at: [0, 1.45, 0], from: camera.position, relativeTo: nil)
        anchor.addChild(camera)
    }

    // MARK: - Lighting

    private func configureLighting() {
        // Key light (warm, from upper right)
        let keyLight = DirectionalLight()
        keyLight.light.color = UIColor(white: 1.0, alpha: 1.0)
        keyLight.light.intensity = 2000
        keyLight.look(at: [0, 1.5, 0], from: [1, 2.5, 1.5], relativeTo: nil)
        keyLight.shadow = .init()
        anchor.addChild(keyLight)

        // Fill light (cool, from left)
        let fillLight = DirectionalLight()
        fillLight.light.color = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        fillLight.light.intensity = 800
        fillLight.look(at: [0, 1.5, 0], from: [-1.5, 1.8, 1.0], relativeTo: nil)
        anchor.addChild(fillLight)

        // Rim light (behind, for edge separation)
        let rimLight = DirectionalLight()
        rimLight.light.color = UIColor(white: 1.0, alpha: 1.0)
        rimLight.light.intensity = 600
        rimLight.look(at: [0, 1.5, 0], from: [0.3, 2.0, -1.5], relativeTo: nil)
        anchor.addChild(rimLight)

        // IBL for ambient
        if let envResource = try? EnvironmentResource.load(named: "studio") {
            arView.environment.lighting.resource = envResource
        }
    }

    // MARK: - Positioning

    private func positionAvatar(_ entity: Entity) {
        let bounds = entity.visualBounds(relativeTo: nil)
        let height = bounds.extents.y
        let targetHeight: Float = 2.0

        if height > 0 && height != targetHeight {
            let scale = targetHeight / height
            entity.scale = [scale, scale, scale]
        }

        let updatedBounds = entity.visualBounds(relativeTo: nil)
        let centerY = (updatedBounds.min.y + updatedBounds.max.y) / 2
        entity.position.y -= centerY - 1.0
    }

    // MARK: - Placeholder

    private func loadPlaceholder() async throws -> Entity {
        let mesh = MeshResource.generateSphere(radius: 0.3)
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .systemBlue)
        material.roughness = .init(floatLiteral: 0.3)
        material.metallic = .init(floatLiteral: 0.0)

        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = [0, 1.5, 0]
        return entity
    }
}
