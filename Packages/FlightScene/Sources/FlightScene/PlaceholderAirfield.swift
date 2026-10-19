import Foundation
import RealityKit

/// A greybox airfield (ground, two runways and a helipad) lit by one sun.
///
/// Placeholder until Phase 2 builds the field from level data. Uses the
/// field's conventions: field `(x, y)` maps to `(x, height, -y)`, and headings
/// are radians counter-clockwise from `+x`.
enum PlaceholderAirfield {
    /// Field size in metres, with the 160 × 100 playfield's proportions.
    static let size: SIMD2<Float> = [1.0, 0.625]

    static func make() -> Entity {
        let root = Entity()
        root.name = "PlaceholderAirfield"

        let ground = ModelEntity(
            mesh: .generateBox(width: size.x, height: 0.02, depth: size.y, cornerRadius: 0.004),
            materials: [matte(red: 0.55, green: 0.70, blue: 0.46)]
        )
        ground.position.y = -0.01
        root.addChild(ground)

        root.addChild(runway(length: 0.33, width: 0.03, center: [-0.1, -0.07], heading: 0))
        root.addChild(runway(length: 0.18, width: 0.024, center: [0.06, 0.13], heading: .pi / 4))

        let helipad = ModelEntity(
            mesh: .generateCylinder(height: 0.004, radius: 0.025),
            materials: [matte(red: 0.42, green: 0.45, blue: 0.48)]
        )
        helipad.position = [0.33, 0.002, -0.14]
        root.addChild(helipad)

        let sun = Entity()
        sun.components.set(DirectionalLightComponent())
        sun.look(at: .zero, from: [0.4, 1.2, 0.6], relativeTo: nil)
        root.addChild(sun)

        return root
    }

    #if !os(visionOS)
    /// A camera about 55° above the horizon, far enough back to fit the field
    /// on a landscape screen. On visionOS the viewer's own eyes are the camera.
    static func makeCamera() -> Entity {
        let pitch: Float = 55 * .pi / 180
        let distance: Float = 1.6
        let camera = Entity()
        camera.name = "PlaceholderCamera"
        camera.components.set(
            PerspectiveCameraComponent(near: 0.01, far: 20, fieldOfViewInDegrees: 30)
        )
        camera.look(
            at: .zero,
            from: [0, distance * sin(pitch), distance * cos(pitch)],
            relativeTo: nil
        )
        return camera
    }
    #endif

    private static func runway(
        length: Float, width: Float, center: SIMD2<Float>, heading: Float
    ) -> Entity {
        let runway = ModelEntity(
            mesh: .generateBox(width: length, height: 0.004, depth: width),
            materials: [matte(red: 0.36, green: 0.38, blue: 0.40)]
        )
        runway.position = [center.x, 0.002, -center.y]
        runway.orientation = simd_quatf(angle: heading, axis: [0, 1, 0])
        return runway
    }

    private static func matte(red: CGFloat, green: CGFloat, blue: CGFloat) -> SimpleMaterial {
        SimpleMaterial(
            color: .init(red: red, green: green, blue: blue, alpha: 1),
            roughness: 0.9,
            isMetallic: false
        )
    }
}
