// swift-tools-version: 6.2

import PackageDescription

// SwiftUI code, so everything defaults to the main actor.
let swiftSettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "FlightUI",
    platforms: [.iOS(.v26), .macOS(.v26), .visionOS(.v26)],
    products: [
        .library(name: "FlightUI", targets: ["FlightUI"])
    ],
    dependencies: [
        .package(path: "../FlightCore"),
        .package(path: "../FlightScene"),
        .package(path: "../FlightServices"),
    ],
    targets: [
        .target(
            name: "FlightUI",
            dependencies: [
                .product(name: "FlightCore", package: "FlightCore"),
                .product(name: "FlightScene", package: "FlightScene"),
                .product(name: "FlightServices", package: "FlightServices"),
            ],
            swiftSettings: swiftSettings
        )
    ]
)
