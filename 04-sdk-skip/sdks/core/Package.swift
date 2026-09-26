// swift-tools-version: 6.1
// FightDeck Skip core — everything both features share, transpiled to Kotlin on Android
// (Skip Lite): FightCore business logic plus the design-system pieces (typography, theme
// colours, preset chips) that deposit and betslip would otherwise each carry a copy of.
import PackageDescription

let buildMode = Context.environment["FIGHTDECK_BUILDING_SDK"]
let buildFromSource = buildMode == "1" || buildMode == "ios"
// `ios` builds the iOS framework from source without Skip. No source here imports a Skip
// module: the screens are SwiftUI, and on iOS Skip's libraries are their Android half compiled
// out. Linked anyway, each framework carried its own static copy of SkipUI. `1` keeps Skip and
// its transpiler for the Android export and the fixture tests.
let transpile = buildMode == "1"

let skipProducts: [Target.Dependency] = transpile
    ? [
        .product(name: "SkipFoundation", package: "skip-foundation"),
        .product(name: "SkipUI", package: "skip-ui"),
    ]
    : []

let coreBinary: Target = buildFromSource
    ? .target(
        name: "FightDeckCoreBinary",
        dependencies: skipProducts,
        path: "Sources/FightDeckCore",
        plugins: transpile ? [.plugin(name: "skipstone", package: "skip")] : []
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

// The Skip packages are the transpiler's own toolchain. They are used by the transpiling
// source build and its `skipstone` plugin, and by nothing at all otherwise — the xcframework
// carries the compiled result. Declared unconditionally they made Xcode warn "dependency is
// not used by any target" nine times over a demo-app build, and clone roughly 10 MB of Skip
// sources the app never compiles.
let skipDependencies: [Package.Dependency] = transpile
    ? [
        .package(url: "https://github.com/skiptools/skip.git", exact: "1.9.11"),
        .package(url: "https://github.com/skiptools/skip-foundation.git", exact: "1.4.6"),
        .package(url: "https://github.com/skiptools/skip-ui.git", exact: "1.60.0"),
    ]
    : []

let package = Package(
    name: "FightDeckCore",
    defaultLocalization: "en",
    platforms: [
        .iOS("26.0"),
        // Not for an app: `swift test` builds this package for the Mac it runs on, and without a
        // macOS entry SwiftPM assumes 10.13 — below the macOS 13 SkipFoundation and SkipUI
        // declare, so the fixture tests would not even resolve. 26 because the core's chips use
        // Liquid Glass, which is as new on the Mac as it is on iOS.
        .macOS("26.0"),
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
