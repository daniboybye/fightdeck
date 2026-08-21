// swift-tools-version: 6.0
import PackageDescription

let useLocal = Context.environment["FIGHTDECK_LOCAL_SDK"] == "1"
let useReleasePath = Context.environment["FIGHTDECK_RELEASE_PATH"] == "1"
let sdkVersion = "0.1.0"
let releaseBase = Context.environment["FIGHTDECK_RELEASE_BASE_URL"]
    ?? "https://github.com/fightdeck/fightdeck/releases/download/sdk-v\(sdkVersion)"
let releaseChecksum = "1807b0db5fa0b0f49d9cb27d9c8bfb36f2be9e848d8907929619aed46fe44ab5"

let betslipTarget: Target = useLocal
    ? .target(
        name: "BetslipSDKBinary",
        dependencies: [
            .product(name: "FightDeckRNRuntime", package: "core"),
        ],
        path: "ios/Sources/BetslipSDK",
        swiftSettings: [
            .swiftLanguageMode(.v6),
            .unsafeFlags(["-strict-concurrency=minimal"]),
        ]
    )
    : useReleasePath
        ? .binaryTarget(
            name: "BetslipSDKBinary",
            path: "../../../tools/out/release/rn/BetslipSDK.xcframework.zip"
        )
        : .binaryTarget(
            name: "BetslipSDKBinary",
            url: "\(releaseBase)/BetslipSDK.xcframework.zip",
            checksum: releaseChecksum
        )

let package = Package(
    name: "BetslipSDK",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "BetslipSDK", targets: ["BetslipSDK"]),
    ],
    dependencies: [
        .package(path: "../core"),
    ],
    targets: [
        betslipTarget,
        .target(
            name: "BetslipSDK",
            dependencies: [
                "BetslipSDKBinary",
                .product(name: "FightDeckRNRuntime", package: "core"),
            ],
            path: "ios/Umbrella"
        ),
    ]
)
