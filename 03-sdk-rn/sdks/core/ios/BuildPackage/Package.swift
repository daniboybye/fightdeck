// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "FightDeckRNRuntime",
    platforms: [.iOS("26.0")],
    products: [.library(name: "FightDeckRNRuntimeBinary", targets: ["FightDeckRNRuntimeBinary"])],
    targets: [.target(
        name: "FightDeckRNRuntimeBinary",
        swiftSettings: [
            .swiftLanguageMode(.v6),
            .unsafeFlags(["-strict-concurrency=minimal"]),
        ]
    )]
)
