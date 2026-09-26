// swift-tools-version: 6.1
import PackageDescription

let buildMode = Context.environment["FIGHTDECK_BUILDING_SDK"]
let buildFromSource = buildMode == "1" || buildMode == "ios"
// `ios` builds the iOS framework without Skip; see core/Package.swift.
let transpile = buildMode == "1"

let skipProducts: [Target.Dependency] = transpile
    ? [
        .product(name: "SkipFoundation", package: "skip-foundation"),
        .product(name: "SkipUI", package: "skip-ui"),
    ]
    : []

let betslipBinary: Target = buildFromSource
    ? .target(
        name: "FightDeckBetslipBinary",
        dependencies: [
            .product(name: "FightDeckCore", package: "FightDeckCore"),
        ] + skipProducts,
        path: "Sources/FightDeckBetslip",
        plugins: transpile ? [.plugin(name: "skipstone", package: "skip")] : []
    )
    : .binaryTarget(
        name: "FightDeckBetslipBinary",
        path: "out/FightDeckBetslip.xcframework"
    )

// The xcframework this package is distributed as contains a dylib, and SwiftPM only
// links one for a dynamic product. The source-only packaging build therefore uses a
// dynamic product; normal host builds consume the local xcframework.
let fightDeckBetslipLibrary: Product = buildFromSource
    ? .library(name: "FightDeckBetslip", type: .dynamic, targets: ["FightDeckBetslip"])
    : .library(name: "FightDeckBetslip", targets: ["FightDeckBetslip"])

// Only the source path needs the transpiler's own packages; the binary path links a
// compiled xcframework. See the note in core/Package.swift.
let skipDependencies: [Package.Dependency] = transpile
    ? [
        .package(url: "https://github.com/skiptools/skip.git", exact: "1.9.11"),
        .package(url: "https://github.com/skiptools/skip-foundation.git", exact: "1.4.6"),
        .package(url: "https://github.com/skiptools/skip-ui.git", exact: "1.60.0"),
    ]
    : []

let package = Package(
    name: "FightDeckBetslip",
    defaultLocalization: "en",
    platforms: [
        .iOS("26.0"),
    ],
    products: [
        fightDeckBetslipLibrary,
    ],
    // FightDeckCore is needed in both modes: the umbrella target re-exports it either way.
    dependencies: skipDependencies + [
        .package(name: "FightDeckCore", path: "../core"),
    ],
    targets: [
        betslipBinary,
        .target(
            name: "FightDeckBetslip",
            dependencies: [
                "FightDeckBetslipBinary",
                .product(name: "FightDeckCore", package: "FightDeckCore"),
            ],
            path: "Umbrella"
        ),
    ]
)
