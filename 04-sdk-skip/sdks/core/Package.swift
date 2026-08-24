// swift-tools-version: 6.1
// FightDeck Skip core — headless FightCore, transpiled to Kotlin on Android (Skip Lite).
import PackageDescription

let useLocal = Context.environment["FIGHTDECK_LOCAL_SDK"] == "1"
let useReleasePath = Context.environment["FIGHTDECK_RELEASE_PATH"] == "1"
let sdkVersion = "0.1.0"
let releaseBase = Context.environment["FIGHTDECK_RELEASE_BASE_URL"]
    ?? "https://github.com/fightdeck/fightdeck/releases/download/sdk-v\(sdkVersion)"
let releaseChecksum = "9437103e805ae5fbb024cb15ad27e2fb9547c6c06f53eda5b379a892ebf428a9"

let coreBinary: Target = useLocal
    ? .target(
        name: "FightDeckCoreBinary",
        dependencies: [
            .product(name: "SkipFoundation", package: "skip-foundation"),
        ],
        path: "Sources/FightDeckCore",
        plugins: [
            .plugin(name: "skipstone", package: "skip"),
        ]
    )
    : useReleasePath
        ? .binaryTarget(
            name: "FightDeckCoreBinary",
            path: "../../../tools/out/release/skip/FightDeckCore.xcframework.zip"
        )
        : .binaryTarget(
            name: "FightDeckCoreBinary",
            url: "\(releaseBase)/FightDeckCore.xcframework.zip",
            checksum: releaseChecksum
        )

// The xcframework this package is distributed as contains a dylib, and SwiftPM only
// links one for a dynamic product. Consumers of a published release get that dylib
// through the binary target above, so only the source build needs the switch.
let coreLibrary: Product = useLocal
    ? .library(name: "FightDeckCore", type: .dynamic, targets: ["FightDeckCore"])
    : .library(name: "FightDeckCore", targets: ["FightDeckCore"])

let package = Package(
    name: "FightDeckCore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        coreLibrary,
    ],
    dependencies: [
        .package(url: "https://github.com/skiptools/skip.git", exact: "1.9.6"),
        .package(url: "https://github.com/skiptools/skip-foundation.git", exact: "1.4.3"),
    ],
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
