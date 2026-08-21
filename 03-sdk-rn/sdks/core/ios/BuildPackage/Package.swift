// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "FightDeckRNRuntime",
    platforms: [.iOS("26.0")],
    products: [.library(name: "FightDeckRNRuntime", targets: ["FightDeckRNRuntime"])],
    targets: [.target(
        name: "FightDeckRNRuntime",
        swiftSettings: [
            .swiftLanguageMode(.v6),
            .unsafeFlags(["-strict-concurrency=minimal"]),
        ]
    )]
)
