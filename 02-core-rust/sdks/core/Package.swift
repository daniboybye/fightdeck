// swift-tools-version: 6.0
import PackageDescription

let useLocal = Context.environment["FIGHTDECK_LOCAL_SDK"] == "1"
let useReleasePath = Context.environment["FIGHTDECK_RELEASE_PATH"] == "1"
let sdkVersion = "0.1.0"
let releaseBase = Context.environment["FIGHTDECK_RELEASE_BASE_URL"]
    ?? "https://github.com/fightdeck/fightdeck/releases/download/sdk-v\(sdkVersion)"
// Belongs to the zip that release-sdk.yml publishes, and that workflow prints the value to
// paste here. Local rebuilds produce a different sum because zip records timestamps, which is
// why the development loop goes through FIGHTDECK_LOCAL_SDK rather than this path.
let releaseChecksum = "59790ae786f9a3883f750ab04521ada04f38135b29674f701829aae705a7f462"

// Only the Rust staticlib travels in the xcframework. The C header and the generated Swift
// are written into Sources by build-xcframework.sh, because this repo regenerates bindings
// rather than committing them.
let rustLibrary: Target = useLocal
    ? .binaryTarget(
        name: "FightCoreRust",
        path: "out/FightCore.xcframework"
    )
    : useReleasePath
        ? .binaryTarget(
            name: "FightCoreRust",
            path: "out/FightCore.xcframework.zip"
        )
        : .binaryTarget(
            name: "FightCoreRust",
            url: "\(releaseBase)/FightCore.xcframework.zip",
            checksum: releaseChecksum
        )

let package = Package(
    name: "FightCore",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "FightCore", targets: ["FightCore"]),
    ],
    targets: [
        rustLibrary,
        .target(
            name: "fightcoreFFI",
            dependencies: ["FightCoreRust"]
        ),
        // UniFFI emits callback vtables and global handle maps that Swift 6 rejects, so the
        // bindings compile in Swift 5 mode. The relaxation stops at this target: the app that
        // consumes the package builds with complete strict concurrency.
        .target(
            name: "FightCore",
            dependencies: ["fightcoreFFI"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
