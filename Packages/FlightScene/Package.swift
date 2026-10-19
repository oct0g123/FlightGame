// swift-tools-version: 6.2

import PackageDescription

// RealityKit and SwiftUI code, so everything defaults to the main actor.
let swiftSettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "FlightScene",
    platforms: [.iOS(.v26), .macOS(.v26), .visionOS(.v26)],
    products: [
        .library(name: "FlightScene", targets: ["FlightScene"])
    ],
    dependencies: [
        .package(path: "../FlightCore"),
        .package(path: "../FlightContent"),
    ],
    targets: [
        .target(
            name: "FlightScene",
            dependencies: [
                .product(name: "FlightCore", package: "FlightCore"),
                .product(name: "FlightContent", package: "FlightContent"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "FlightSceneTests",
            dependencies: ["FlightScene"],
            swiftSettings: swiftSettings
        ),
    ]
)
