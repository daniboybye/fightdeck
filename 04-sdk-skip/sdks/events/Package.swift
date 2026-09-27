// swift-tools-version: 6.1
// FightDeck Skip events — the fight catalogue: reading the JSON dataset both apps ship and
// turning it into the strings they put on screen. The DTOs themselves live in FightDeckCore
// because the betting logic and the fighter screen both already speak them; this module is
// the loading and formatting the two hosts used to hand-write once per platform.
import PackageDescription

let buildMode = Context.environment["FIGHTDECK_BUILDING_SDK"]
let packaged = buildMode == "1" || buildMode == "ios"
// Unset: compiled into the iOS app from source. See core/Package.swift for the modes.
let transpile = buildMode == "1"

let skipProducts: [Target.Dependency] = transpile
    ? [
        .product(name: "SkipFoundation", package: "skip-foundation"),
    ]
    : []

let eventsBinary: Target = .target(
    name: "FightDeckEventsBinary",
    dependencies: [
        .product(name: "FightDeckCore", package: "FightDeckCore"),
    ] + skipProducts,
    path: "Sources/FightDeckEvents",
    plugins: transpile ? [.plugin(name: "skipstone", package: "skip")] : []
)

// Statically linked into the app. Only a packaged build is dynamic: the xcframework holds a
// dylib, and SwiftPM only produces one for a dynamic product.
let fightDeckEventsLibrary: Product = packaged
    ? .library(name: "FightDeckEvents", type: .dynamic, targets: ["FightDeckEvents"])
    : .library(name: "FightDeckEvents", targets: ["FightDeckEvents"])

// Only the source path needs the transpiler's own packages; the binary path links a
// compiled xcframework. No skip-ui here — this module draws nothing. See core/Package.swift.
let skipDependencies: [Package.Dependency] = transpile
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
