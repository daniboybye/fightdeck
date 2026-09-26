// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FightSlip",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
    ],
    products: [
        .library(
            name: "FightSlip",
            targets: ["FightSlip"]
        ),
    ],
    dependencies: [
        .package(path: "../core"),
    ],
    targets: [
        .target(
            name: "FightSlip",
            dependencies: [.product(name: "FightCore", package: "core")],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "FightSlipTests",
            dependencies: ["FightSlip"]
        ),
    ]
)
