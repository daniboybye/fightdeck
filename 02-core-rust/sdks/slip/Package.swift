// swift-tools-version: 6.0
import PackageDescription

// The staticlib already contains the fightcore kernel it was compiled against; the app-level
// linker keeps one copy of the shared objects across all three SDKs.
let rustLibrary: Target = .binaryTarget(
    name: "FightSlipRust",
    path: "out/FightSlip.xcframework"
)

let package = Package(
    name: "FightSlip",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "FightSlip", targets: ["FightSlip"]),
    ],
    // For the Swift bindings only: they use FightCore's records (BoutIndex) and converters.
    dependencies: [
        .package(path: "../core"),
    ],
    targets: [
        rustLibrary,
        .target(
            name: "fightslipFFI",
            dependencies: ["FightSlipRust"]
        ),
        .target(
            name: "FightSlip",
            dependencies: ["fightslipFFI", .product(name: "FightCore", package: "core")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
