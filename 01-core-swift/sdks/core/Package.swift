// swift-tools-version: 6.0
import PackageDescription

// Pure Swift. The Android facade that jextract reads lives in ../android, which links this
// package into one shared object with the other two.
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
