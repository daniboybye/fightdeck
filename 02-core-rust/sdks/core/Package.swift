// swift-tools-version: 6.0
import PackageDescription

// Only the Rust staticlib travels in the xcframework. The C header and the generated Swift
// are written into Sources by build-xcframework.sh, because this repo regenerates bindings
// rather than committing them.
let rustLibrary: Target = .binaryTarget(
    name: "FightCoreRust",
    path: "out/FightCore.xcframework"
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
