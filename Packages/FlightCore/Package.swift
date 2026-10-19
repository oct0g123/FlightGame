// swift-tools-version: 6.2

import PackageDescription

// FlightCore stays nonisolated: plain value types that run anywhere, including Linux CI.
let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "FlightCore",
    platforms: [.iOS(.v26), .macOS(.v26), .visionOS(.v26)],
    products: [
        .library(name: "FlightCore", targets: ["FlightCore"])
    ],
    targets: [
        .target(name: "FlightCore", swiftSettings: swiftSettings),
        .testTarget(
            name: "FlightCoreTests",
            dependencies: ["FlightCore"],
            swiftSettings: swiftSettings
        ),
    ]
)
