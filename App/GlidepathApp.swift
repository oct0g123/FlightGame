import FlightUI
import SwiftUI

@main
struct GlidepathApp: App {
    var body: some Scene {
        #if os(visionOS)
        WindowGroup(id: "airfield") {
            RootView()
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 1.2, height: 0.45, depth: 0.8, in: .meters)
        #else
        WindowGroup {
            RootView()
        }
        #if os(macOS)
        .defaultSize(width: 1280, height: 800)
        #endif
        #endif
    }
}
