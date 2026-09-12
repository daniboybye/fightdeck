// swift-tools-version: 6.1
import PackageDescription

let useLocal = Context.environment["FIGHTDECK_LOCAL_SDK"] == "1"
let useReleasePath = Context.environment["FIGHTDECK_RELEASE_PATH"] == "1"
let sdkVersion = "0.1.0"
let releaseBase = Context.environment["FIGHTDECK_RELEASE_BASE_URL"]
    ?? "https://github.com/fightdeck/fightdeck/releases/download/sdk-v\(sdkVersion)"
let releaseChecksum = "2063e029e7449bf6f0864e9ebeee4b4be93f5c194810d491e4ecf62c5e2f8117"

let betslipBinary: Target = useLocal
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
    : useReleasePath
        ? .binaryTarget(
            name: "FightDeckBetslipBinary",
            path: "../../../tools/out/release/skip/FightDeckBetslip.xcframework.zip"
        )
        : .binaryTarget(
            name: "FightDeckBetslipBinary",
            url: "\(releaseBase)/FightDeckBetslip.xcframework.zip",
            checksum: releaseChecksum
        )

// The xcframework this package is distributed as contains a dylib, and SwiftPM only
// links one for a dynamic product. Consumers of a published release get that dylib
// through the binary target above, so only the source build needs the switch.
let fightDeckBetslipLibrary: Product = useLocal
    ? .library(name: "FightDeckBetslip", type: .dynamic, targets: ["FightDeckBetslip"])
    : .library(name: "FightDeckBetslip", targets: ["FightDeckBetslip"])

let package = Package(
    name: "FightDeckBetslip",
    defaultLocalization: "en",
    platforms: [
        .iOS("26.0"),
        .macOS(.v14),
    ],
    products: [
        fightDeckBetslipLibrary,
    ],
    dependencies: [
        .package(url: "https://github.com/skiptools/skip.git", exact: "1.9.8"),
        .package(url: "https://github.com/skiptools/skip-foundation.git", exact: "1.4.4"),
        .package(url: "https://github.com/skiptools/skip-ui.git", exact: "1.59.3"),
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
