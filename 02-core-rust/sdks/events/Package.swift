// swift-tools-version: 6.0
import PackageDescription

let rustLibrary: Target = .binaryTarget(
    name: "FightEventsRust",
    path: "out/FightEvents.xcframework"
)

let package = Package(
    name: "FightEvents",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "FightEvents", targets: ["FightEvents"]),
    ],
    // For the Swift bindings only: they use FightCore's records (BoutIndex) and converters.
    dependencies: [
        .package(path: "../core"),
    ],
    targets: [
        rustLibrary,
        .target(
            name: "fighteventsFFI",
            dependencies: ["FightEventsRust"]
        ),
        .target(
            name: "FightEvents",
            dependencies: ["fighteventsFFI", .product(name: "FightCore", package: "core")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
