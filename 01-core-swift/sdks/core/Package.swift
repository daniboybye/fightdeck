// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FightCore",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
    ],
    products: [
        .library(
            name: "FightCore",
            targets: ["FightCore"]
        ),
        // Android loads code as a shared object, and SwiftPM only emits one for a product
        // declared dynamic. Apple builds keep using the static product above, which is
        // what the xcframework is assembled from.
        .library(
            name: "FightCoreShared",
            type: .dynamic,
            targets: ["FightCore"]
        ),
    ],
    targets: [
        .target(
            name: "FightCore",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "FightCoreTests",
            dependencies: ["FightCore"]
        ),
    ]
)
