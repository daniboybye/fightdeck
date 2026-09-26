// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FightEvents",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
    ],
    products: [
        .library(
            name: "FightEvents",
            targets: ["FightEvents"]
        ),
    ],
    dependencies: [
        .package(path: "../core"),
    ],
    targets: [
        .target(
            name: "FightEvents",
            dependencies: [.product(name: "FightCore", package: "core")],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "FightEventsTests",
            dependencies: ["FightEvents"]
        ),
    ]
)
