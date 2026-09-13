// swift-tools-version: 6.1
import PackageDescription

let useLocal = Context.environment["FIGHTDECK_LOCAL_SDK"] == "1"
let useReleasePath = Context.environment["FIGHTDECK_RELEASE_PATH"] == "1"
let sdkVersion = "0.1.0"
let releaseBase = Context.environment["FIGHTDECK_RELEASE_BASE_URL"]
    ?? "https://github.com/fightdeck/fightdeck/releases/download/sdk-v\(sdkVersion)"
let releaseChecksum = "0000000000000000000000000000000000000000000000000000000000000000"

let fighterBinary: Target = useLocal
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
    : useReleasePath
        ? .binaryTarget(
            name: "FightDeckFighterBinary",
            path: "../../../tools/out/release/skip/FightDeckFighter.xcframework.zip"
        )
        : .binaryTarget(
            name: "FightDeckFighterBinary",
            url: "\(releaseBase)/FightDeckFighter.xcframework.zip",
            checksum: releaseChecksum
        )

// The xcframework this package is distributed as contains a dylib, and SwiftPM only
// links one for a dynamic product. Consumers of a published release get that dylib
// through the binary target above, so only the source build needs the switch.
let fightDeckFighterLibrary: Product = useLocal
    ? .library(name: "FightDeckFighter", type: .dynamic, targets: ["FightDeckFighter"])
    : .library(name: "FightDeckFighter", targets: ["FightDeckFighter"])

let package = Package(
    name: "FightDeckFighter",
    defaultLocalization: "en",
    platforms: [
        .iOS("26.0"),
        .macOS(.v14),
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
