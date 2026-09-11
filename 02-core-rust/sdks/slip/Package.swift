// swift-tools-version: 6.0
import PackageDescription

let useLocal = Context.environment["FIGHTDECK_LOCAL_SDK"] == "1"
let useReleasePath = Context.environment["FIGHTDECK_RELEASE_PATH"] == "1"
let sdkVersion = "0.1.0"
let releaseBase = Context.environment["FIGHTDECK_RELEASE_BASE_URL"]
    ?? "https://github.com/fightdeck/fightdeck/releases/download/sdk-v\(sdkVersion)"
// Printed by release-sdk.yml for the published zip; see the note in core/Package.swift.
let releaseChecksum = "cbfa20ba31cad28ba1e07c823cef2b43362775f1e019313ceb1102ade238b853"

// The staticlib already contains the fightcore kernel it was compiled against, so this
// package does not depend on FightCore. The app-level linker keeps one copy of the shared
// objects across all three SDKs.
let rustLibrary: Target = useLocal
    ? .binaryTarget(
        name: "FightSlipRust",
        path: "out/FightSlip.xcframework"
    )
    : useReleasePath
        ? .binaryTarget(
            name: "FightSlipRust",
            path: "out/FightSlip.xcframework.zip"
        )
        : .binaryTarget(
            name: "FightSlipRust",
            url: "\(releaseBase)/FightSlip.xcframework.zip",
            checksum: releaseChecksum
        )

let package = Package(
    name: "FightSlip",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "FightSlip", targets: ["FightSlip"]),
    ],
    targets: [
        rustLibrary,
        .target(
            name: "fightslipFFI",
            dependencies: ["FightSlipRust"]
        ),
        .target(
            name: "FightSlip",
            dependencies: ["fightslipFFI"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
