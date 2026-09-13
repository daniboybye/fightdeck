// swift-tools-version: 6.1
// FightDeck Skip events — the fight catalogue: reading the JSON dataset both apps ship and
// turning it into the strings they put on screen. The DTOs themselves live in FightDeckCore
// because the betting logic and the fighter screen both already speak them; this module is
// the loading and formatting the two hosts used to hand-write once per platform.
import PackageDescription

let useLocal = Context.environment["FIGHTDECK_LOCAL_SDK"] == "1"
let useReleasePath = Context.environment["FIGHTDECK_RELEASE_PATH"] == "1"
let sdkVersion = "0.1.0"
let releaseBase = Context.environment["FIGHTDECK_RELEASE_BASE_URL"]
    ?? "https://github.com/fightdeck/fightdeck/releases/download/sdk-v\(sdkVersion)"
let releaseChecksum = "0000000000000000000000000000000000000000000000000000000000000000"

let eventsBinary: Target = useLocal
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
    : useReleasePath
        ? .binaryTarget(
            name: "FightDeckEventsBinary",
            path: "../../../tools/out/release/skip/FightDeckEvents.xcframework.zip"
        )
        : .binaryTarget(
            name: "FightDeckEventsBinary",
            url: "\(releaseBase)/FightDeckEvents.xcframework.zip",
            checksum: releaseChecksum
        )

// The xcframework this package is distributed as contains a dylib, and SwiftPM only
// links one for a dynamic product. Consumers of a published release get that dylib
// through the binary target above, so only the source build needs the switch.
let fightDeckEventsLibrary: Product = useLocal
    ? .library(name: "FightDeckEvents", type: .dynamic, targets: ["FightDeckEvents"])
    : .library(name: "FightDeckEvents", targets: ["FightDeckEvents"])

let package = Package(
    name: "FightDeckEvents",
    defaultLocalization: "en",
    platforms: [
        .iOS("26.0"),
        .macOS(.v14),
    ],
    products: [
        fightDeckEventsLibrary,
    ],
    dependencies: [
        .package(url: "https://github.com/skiptools/skip.git", exact: "1.9.8"),
        .package(url: "https://github.com/skiptools/skip-foundation.git", exact: "1.4.4"),
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
