// swift-tools-version: 6.0
import PackageDescription

let useLocal = Context.environment["FIGHTDECK_LOCAL_SDK"] == "1"
let useReleasePath = Context.environment["FIGHTDECK_RELEASE_PATH"] == "1"
let sdkVersion = "0.1.0"
let releaseBase = Context.environment["FIGHTDECK_RELEASE_BASE_URL"]
    ?? "https://github.com/fightdeck/fightdeck/releases/download/sdk-v\(sdkVersion)"
let releaseChecksum = "4e5854f13a3aa353926ffeb648457225fcfafd5f23246d5d938a88c5fa9711f1"

let runtimeTarget: Target = useLocal
    ? .target(
        name: "FightDeckRNRuntimeBinary",
        path: "ios/Sources/FightDeckRNRuntime",
        exclude: ["Native/FightDeckNativeBadgeComponentView.mm"],
        swiftSettings: [
            .swiftLanguageMode(.v6),
            .unsafeFlags(["-strict-concurrency=minimal"]),
        ]
    )
    : useReleasePath
        ? .binaryTarget(
            name: "FightDeckRNRuntimeBinary",
            path: "../../../tools/out/release/rn/FightDeckRNRuntime.xcframework.zip"
        )
        : .binaryTarget(
            name: "FightDeckRNRuntimeBinary",
            url: "\(releaseBase)/FightDeckRNRuntime.xcframework.zip",
            checksum: releaseChecksum
        )

let package = Package(
    name: "FightDeckRNRuntime",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "FightDeckRNRuntime", targets: ["FightDeckRNRuntime"]),
    ],
    targets: [
        runtimeTarget,
        .target(
            name: "FightDeckRNRuntime",
            dependencies: ["FightDeckRNRuntimeBinary"],
            path: "ios/Umbrella"
        ),
    ]
)
