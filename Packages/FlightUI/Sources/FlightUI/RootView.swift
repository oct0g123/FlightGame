import FlightScene
import SwiftUI

/// The app's root view.
///
/// During Phase 1, iPhone, iPad and Mac open the 2D playtest; the 3D preview
/// is in its options menu. Vision Pro shows the 3D placeholder until Phase 3.
public struct RootView: View {
    public init() {}

    public var body: some View {
        #if os(visionOS)
        GameView()
            .ornament(attachmentAnchor: .scene(.bottomFront)) {
                TitleBadge()
            }
        #else
        PlaytestView()
        #endif
    }
}

/// The game's name on glass.
struct TitleBadge: View {
    var body: some View {
        Text("Glidepath")
            .font(.title2.weight(.semibold))
            .fontDesign(.rounded)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .modifier(SystemGlass())
    }
}

/// The platform's glass behind a view: Liquid Glass on iOS and macOS, the
/// glass material on visionOS.
struct SystemGlass: ViewModifier {
    func body(content: Content) -> some View {
        #if os(visionOS)
        content.glassBackgroundEffect()
        #else
        content.glassEffect()
        #endif
    }
}
