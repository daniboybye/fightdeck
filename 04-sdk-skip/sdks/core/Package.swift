// swift-tools-version: 6.1
// FightDeck Skip core — everything both features share, transpiled to Kotlin on Android
// (Skip Lite): FightCore business logic plus the design-system pieces (typography, theme
// colours, preset chips) that deposit and betslip would otherwise each carry a copy of.
import PackageDescription

let buildFromSource = Context.environment["FIGHTDECK_BUILDING_SDK"] == "1"

let coreBinary: Target = buildFromSource
    ? .target(
        name: "FightDeckCoreBinary",
        dependencies: [
            .product(name: "SkipFoundation", package: "skip-foundation"),
            .product(name: "SkipUI", package: "skip-ui"),
        ],
        path: "Sources/FightDeckCore",
        plugins: [
            .plugin(name: "skipstone", package: "skip"),
        ]
    )
    : .binaryTarget(
        name: "FightDeckCoreBinary",
        path: "out/FightDeckCore.xcframework"
    )

// The xcframework this package is distributed as contains a dylib, and SwiftPM only
// links one for a dynamic product. The source-only packaging build therefore uses a
// dynamic product; normal host builds consume the local xcframework.
let coreLibrary: Product = buildFromSource
    ? .library(name: "FightDeckCore", type: .dynamic, targets: ["FightDeckCore"])
    : .library(name: "FightDeckCore", targets: ["FightDeckCore"])

// The Skip packages are the transpiler's own toolchain. They are used by the source target
// and its `skipstone` plugin, and by nothing at all on the binary path — the xcframework
// carries the compiled result. Declared unconditionally they made Xcode warn "dependency is
// not used by any target" nine times over a demo-app build, and clone roughly 10 MB of Skip
// sources the app never compiles.
let skipDependencies: [Package.Dependency] = buildFromSource
    ? [
        .package(url: "https://github.com/skiptools/skip.git", exact: "1.9.8"),
        .package(url: "https://github.com/skiptools/skip-foundation.git", exact: "1.4.4"),
        .package(url: "https://github.com/skiptools/skip-ui.git", exact: "1.59.3"),
    ]
    : []

let package = Package(
    name: "FightDeckCore",
    defaultLocalization: "en",
    platforms: [
        .iOS("26.0"),
    ],
    products: [
        coreLibrary,
    ],
    dependencies: skipDependencies,
    targets: [
        coreBinary,
        .target(
            name: "FightDeckCore",
            dependencies: ["FightDeckCoreBinary"],
            path: "Umbrella"
        ),
        .testTarget(
            name: "FightDeckCoreTests",
            dependencies: ["FightDeckCore"],
            path: "Tests/FightDeckCoreTests"
        ),
    ]
)
