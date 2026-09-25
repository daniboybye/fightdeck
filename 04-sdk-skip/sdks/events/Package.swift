// swift-tools-version: 6.1
// FightDeck Skip events — the fight catalogue: reading the JSON dataset both apps ship and
// turning it into the strings they put on screen. The DTOs themselves live in FightDeckCore
// because the betting logic and the fighter screen both already speak them; this module is
// the loading and formatting the two hosts used to hand-write once per platform.
import PackageDescription

let buildFromSource = Context.environment["FIGHTDECK_BUILDING_SDK"] == "1"

let eventsBinary: Target = buildFromSource
    ? .target(
        name: "FightDeckEventsBinary",
        dependencies: [
            .product(name: "FightDeckCore", package: "FightDeckCore"),
            .product(name: "SkipFoundation", package: "skip-foundation"),
        ],
        path: "Sources/FightDeckEvents",
        plugins: [
            .plugin(name: "skipstone", package: "skip"),
        ]
    )
    : .binaryTarget(
        name: "FightDeckEventsBinary",
        path: "out/FightDeckEvents.xcframework"
    )

// The xcframework this package is distributed as contains a dylib, and SwiftPM only
// links one for a dynamic product. The source-only packaging build therefore uses a
// dynamic product; normal host builds consume the local xcframework.
let fightDeckEventsLibrary: Product = buildFromSource
    ? .library(name: "FightDeckEvents", type: .dynamic, targets: ["FightDeckEvents"])
    : .library(name: "FightDeckEvents", targets: ["FightDeckEvents"])

// Only the source path needs the transpiler's own packages; the binary path links a
// compiled xcframework. No skip-ui here — this module draws nothing. See core/Package.swift.
let skipDependencies: [Package.Dependency] = buildFromSource
    ? [
        .package(url: "https://github.com/skiptools/skip.git", exact: "1.9.11"),
        .package(url: "https://github.com/skiptools/skip-foundation.git", exact: "1.4.6"),
    ]
    : []

let package = Package(
    name: "FightDeckEvents",
    defaultLocalization: "en",
    platforms: [
        .iOS("26.0"),
    ],
    products: [
        fightDeckEventsLibrary,
    ],
    // FightDeckCore is needed in both modes: the umbrella target re-exports it either way.
    dependencies: skipDependencies + [
        .package(name: "FightDeckCore", path: "../core"),
    ],
    targets: [
        eventsBinary,
        .target(
            name: "FightDeckEvents",
            dependencies: [
                "FightDeckEventsBinary",
                .product(name: "FightDeckCore", package: "FightDeckCore"),
            ],
            path: "Umbrella"
        ),
    ]
)
