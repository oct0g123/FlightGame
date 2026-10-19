import RealityKit
import SwiftUI

/// The game's 3D view.
///
/// For now it shows a greybox airfield, which proves RealityKit renders on
/// every platform. The real scene, camera rig and presenters replace it in
/// Phase 2 (see docs/ROADMAP.md).
public struct GameView: View {
    public init() {}

    public var body: some View {
        #if os(visionOS)
        RealityView { content in
            let airfield = PlaceholderAirfield.make()
            // A volume's origin is its centre, so lower the field to sit near the floor.
            airfield.position.y = -0.18
            content.add(airfield)
        }
        #else
        GeometryReader { proxy in
            RealityView { content in
                // iOS defaults to an AR view of the device camera; the game never wants that.
                content.camera = .virtual
                content.add(PlaceholderAirfield.make())
                content.add(PlaceholderAirfield.makeCamera())
            } update: { content in
                guard proxy.size.height > 0,
                    let camera = content.entities.first(where: {
                        $0.name == PlaceholderAirfield.cameraName
                    })
                else { return }
                let aspect = Float(proxy.size.width / proxy.size.height)
                PlaceholderAirfield.aim(camera, aspect: aspect)
            }
            // RealityView's default environment draws the view's background style.
            .backgroundStyle(Self.sky)
            .background(Self.sky)
        }
        #endif
    }

    /// Soft sky blue behind the field, so the background isn't left to RealityKit's default.
    static let sky = Color(red: 0.72, green: 0.84, blue: 0.93)
}
