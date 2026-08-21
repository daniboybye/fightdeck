// swift-tools-version: 6.1
import PackageDescription

let useLocal = Context.environment["FIGHTDECK_LOCAL_SDK"] == "1"
let useReleasePath = Context.environment["FIGHTDECK_RELEASE_PATH"] == "1"
let sdkVersion = "0.1.0"
let releaseBase = Context.environment["FIGHTDECK_RELEASE_BASE_URL"]
    ?? "https://github.com/fightdeck/fightdeck/releases/download/sdk-v\(sdkVersion)"
let releaseChecksum = "5125ece3a00cca4f513471392bd4e5023c01ec27a2ece68a68281ee03559e2c7"

let depositBinary: Target = useLocal
    ? .target(
        name: "FightDeckDepositBinary",
        dependencies: [
            .product(name: "FightDeckCore", package: "FightDeckCore"),
            .product(name: "SkipFoundation", package: "skip-foundation"),
            .product(name: "SkipUI", package: "skip-ui"),
        ],
        path: "Sources/FightDeckDeposit",
        plugins: [
            .plugin(name: "skipstone", package: "skip"),
        ]
    )
    : useReleasePath
        ? .binaryTarget(
            name: "FightDeckDepositBinary",
            path: "../../../tools/out/release/skip/FightDeckDeposit.xcframework.zip"
        )
        : .binaryTarget(
            name: "FightDeckDepositBinary",
            url: "\(releaseBase)/FightDeckDeposit.xcframework.zip",
            checksum: releaseChecksum
        )

let package = Package(
    name: "FightDeckDeposit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "FightDeckDeposit", targets: ["FightDeckDeposit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/skiptools/skip.git", exact: "1.9.6"),
        .package(url: "https://github.com/skiptools/skip-foundation.git", exact: "1.4.3"),
        .package(url: "https://github.com/skiptools/skip-ui.git", exact: "1.59.2"),
        .package(name: "FightDeckCore", path: "../core"),
    ],
    targets: [
        depositBinary,
        .target(
            name: "FightDeckDeposit",
            dependencies: [
                "FightDeckDepositBinary",
                .product(name: "FightDeckCore", package: "FightDeckCore"),
            ],
            path: "Umbrella"
        ),
    ]
)
