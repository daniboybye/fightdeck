// swift-tools-version: 6.0
import PackageDescription

let useLocal = Context.environment["FIGHTDECK_LOCAL_SDK"] == "1"
let useReleasePath = Context.environment["FIGHTDECK_RELEASE_PATH"] == "1"
let sdkVersion = "0.1.0"
let releaseBase = Context.environment["FIGHTDECK_RELEASE_BASE_URL"]
    ?? "https://github.com/fightdeck/fightdeck/releases/download/sdk-v\(sdkVersion)"
let releaseChecksum = "c1657a2f4be266a23993f21426d8baed4dc725a6aa64626f67ab03a79369d960"

let depositTarget: Target = useLocal
    ? .target(
        name: "DepositSDKBinary",
        dependencies: [
            .product(name: "FightDeckRNRuntime", package: "core"),
        ],
        path: "ios/Sources/DepositSDK",
        swiftSettings: [
            .swiftLanguageMode(.v6),
            .unsafeFlags(["-strict-concurrency=minimal"]),
        ]
    )
    : useReleasePath
        ? .binaryTarget(
            name: "DepositSDKBinary",
            path: "../../../tools/out/release/rn/DepositSDK.xcframework.zip"
        )
        : .binaryTarget(
            name: "DepositSDKBinary",
            url: "\(releaseBase)/DepositSDK.xcframework.zip",
            checksum: releaseChecksum
        )

let package = Package(
    name: "DepositSDK",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "DepositSDK", targets: ["DepositSDK"]),
    ],
    dependencies: [
        .package(path: "../core"),
    ],
    targets: [
        depositTarget,
        .target(
            name: "DepositSDK",
            dependencies: [
                "DepositSDKBinary",
                .product(name: "FightDeckRNRuntime", package: "core"),
            ],
            path: "ios/Umbrella"
        ),
    ]
)
