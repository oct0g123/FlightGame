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
        RealityView { content in
            let airfield = PlaceholderAirfield.make()
            #if os(visionOS)
            // A volume's origin is its centre, so lower the field to sit near the floor.
            airfield.position.y = -0.18
            #else
            content.add(PlaceholderAirfield.makeCamera())
            #endif
            content.add(airfield)
        }
    }
}
