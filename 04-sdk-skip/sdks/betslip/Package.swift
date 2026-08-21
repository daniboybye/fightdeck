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

let package = Package(
    name: "FightDeckBetslip",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "FightDeckBetslip", targets: ["FightDeckBetslip"]),
    ],
    dependencies: [
        .package(url: "https://github.com/skiptools/skip.git", exact: "1.9.6"),
        .package(url: "https://github.com/skiptools/skip-foundation.git", exact: "1.4.3"),
        .package(url: "https://github.com/skiptools/skip-ui.git", exact: "1.59.2"),
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
