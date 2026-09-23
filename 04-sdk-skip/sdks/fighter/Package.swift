// swift-tools-version: 6.1
import PackageDescription

let buildFromSource = Context.environment["FIGHTDECK_BUILDING_SDK"] == "1"

let fighterBinary: Target = buildFromSource
    ? .target(
        name: "FightDeckFighterBinary",
        dependencies: [
            .product(name: "FightDeckCore", package: "FightDeckCore"),
            .product(name: "SkipFoundation", package: "skip-foundation"),
            .product(name: "SkipUI", package: "skip-ui"),
        ],
        path: "Sources/FightDeckFighter",
        plugins: [
            .plugin(name: "skipstone", package: "skip"),
        ]
    )
    : .binaryTarget(
        name: "FightDeckFighterBinary",
        path: "out/FightDeckFighter.xcframework"
    )

// The xcframework this package is distributed as contains a dylib, and SwiftPM only
// links one for a dynamic product. The source-only packaging build therefore uses a
// dynamic product; normal host builds consume the local xcframework.
let fightDeckFighterLibrary: Product = buildFromSource
    ? .library(name: "FightDeckFighter", type: .dynamic, targets: ["FightDeckFighter"])
    : .library(name: "FightDeckFighter", targets: ["FightDeckFighter"])

let package = Package(
    name: "FightDeckFighter",
    defaultLocalization: "en",
    platforms: [
        .iOS("26.0"),
    ],
    products: [
        fightDeckFighterLibrary,
    ],
    dependencies: [
        .package(url: "https://github.com/skiptools/skip.git", exact: "1.9.8"),
        .package(url: "https://github.com/skiptools/skip-foundation.git", exact: "1.4.4"),
        .package(url: "https://github.com/skiptools/skip-ui.git", exact: "1.59.3"),
        .package(name: "FightDeckCore", path: "../core"),
    ],
    targets: [
        fighterBinary,
        .target(
            name: "FightDeckFighter",
            dependencies: [
                "FightDeckFighterBinary",
                .product(name: "FightDeckCore", package: "FightDeckCore"),
            ],
            path: "Umbrella"
        ),
    ]
)
