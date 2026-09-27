// swift-tools-version: 6.1
import PackageDescription

let buildMode = Context.environment["FIGHTDECK_BUILDING_SDK"]
// Unset: compiled into the iOS app from source. See core/Package.swift.
let transpile = buildMode == "1"

let skipProducts: [Target.Dependency] = transpile
    ? [
        .product(name: "SkipFoundation", package: "skip-foundation"),
        .product(name: "SkipUI", package: "skip-ui"),
    ]
    : []

let betslipBinary: Target = .target(
    name: "FightDeckBetslipBinary",
    dependencies: [
        .product(name: "FightDeckCore", package: "FightDeckCore"),
    ] + skipProducts,
    path: "Sources/FightDeckBetslip",
    plugins: transpile ? [.plugin(name: "skipstone", package: "skip")] : []
)

let fightDeckBetslipLibrary: Product = .library(name: "FightDeckBetslip", targets: ["FightDeckBetslip"])

// Only the transpiling build needs Skip's own packages. See the note in core/Package.swift.
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
