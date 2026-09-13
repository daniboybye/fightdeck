// swift-tools-version: 6.0
import PackageDescription

let useLocal = Context.environment["FIGHTDECK_LOCAL_SDK"] == "1"
let useReleasePath = Context.environment["FIGHTDECK_RELEASE_PATH"] == "1"
let sdkVersion = "0.1.0"
let releaseBase = Context.environment["FIGHTDECK_RELEASE_BASE_URL"]
    ?? "https://github.com/fightdeck/fightdeck/releases/download/sdk-v\(sdkVersion)"
let releaseChecksum = "0000000000000000000000000000000000000000000000000000000000000000"

let fighterTarget: Target = useLocal
    ? .target(
        name: "FighterSDKBinary",
        dependencies: [
            .product(name: "FightDeckRNRuntime", package: "core"),
        ],
        path: "ios/Sources/FighterSDK",
        swiftSettings: [
            .swiftLanguageMode(.v6),
            .unsafeFlags(["-strict-concurrency=minimal"]),
        ]
    )
    : useReleasePath
        ? .binaryTarget(
            name: "FighterSDKBinary",
            path: "../../../tools/out/release/rn/FighterSDK.xcframework.zip"
        )
        : .binaryTarget(
            name: "FighterSDKBinary",
            url: "\(releaseBase)/FighterSDK.xcframework.zip",
            checksum: releaseChecksum
        )

let package = Package(
    name: "FighterSDK",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "FighterSDK", targets: ["FighterSDK"]),
    ],
    dependencies: [
        .package(path: "../core"),
    ],
    targets: [
        fighterTarget,
        .target(
            name: "FighterSDK",
            dependencies: [
                "FighterSDKBinary",
                .product(name: "FightDeckRNRuntime", package: "core"),
            ],
            path: "ios/Umbrella"
        ),
    ]
)
