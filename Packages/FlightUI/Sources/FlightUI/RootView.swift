import FlightScene
import SwiftUI

/// The app's root view: the game, with the UI layered over it.
public struct RootView: View {
    public init() {}

    public var body: some View {
        #if os(visionOS)
        GameView()
            .ornament(attachmentAnchor: .scene(.bottomFront)) {
                TitleBadge()
            }
        #else
        ZStack(alignment: .top) {
            GameView()
                .ignoresSafeArea()
            TitleBadge()
                .padding()
        }
        #endif
    }
}

/// The game's name on glass. Stands in for the title screen until Phase 2.
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
