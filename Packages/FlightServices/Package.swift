// swift-tools-version: 6.2

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "FlightServices",
    platforms: [.iOS(.v26), .macOS(.v26), .visionOS(.v26)],
    products: [
        .library(name: "FlightServices", targets: ["FlightServices"])
    ],
    dependencies: [
        .package(path: "../FlightCore")
    ],
    targets: [
        .target(
            name: "FlightServices",
            dependencies: [.product(name: "FlightCore", package: "FlightCore")],
            swiftSettings: swiftSettings
        )
    ]
)
