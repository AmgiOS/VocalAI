import SwiftUI
import RealityKit

/// UIViewRepresentable wrapping RealityKit ARView in non-AR mode for avatar display.
struct AvatarContainerView: UIViewRepresentable {
    let renderer: AvatarRenderer

    func makeUIView(context: Context) -> ARView {
        renderer.arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // No dynamic updates needed — rendering is handled by AvatarRenderer
    }
}

#Preview {
    AvatarContainerView(renderer: AvatarRenderer())
        .ignoresSafeArea()
}
