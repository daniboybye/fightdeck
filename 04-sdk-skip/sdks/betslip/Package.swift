// swift-tools-version: 6.1
import PackageDescription

let buildFromSource = Context.environment["FIGHTDECK_BUILDING_SDK"] == "1"

let betslipBinary: Target = buildFromSource
    ? .target(
        name: "FightDeckBetslipBinary",
        dependencies: [
            .product(name: "FightDeckCore", package: "FightDeckCore"),
            .product(name: "SkipFoundation", package: "skip-foundation"),
            .product(name: "SkipUI", package: "skip-ui"),
        ],
        path: "Sources/FightDeckBetslip",
        plugins: [
            .plugin(name: "skipstone", package: "skip"),
        ]
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
let skipDependencies: [Package.Dependency] = buildFromSource
    ? [
        .package(url: "https://github.com/skiptools/skip.git", exact: "1.9.8"),
        .package(url: "https://github.com/skiptools/skip-foundation.git", exact: "1.4.4"),
        .package(url: "https://github.com/skiptools/skip-ui.git", exact: "1.59.3"),
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
