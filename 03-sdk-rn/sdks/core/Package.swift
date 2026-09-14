// swift-tools-version: 6.0
import PackageDescription

let runtimeTarget: Target = .binaryTarget(
    name: "FightDeckRNRuntime",
    path: "out/FightDeckRNRuntime.xcframework"
)

let package = Package(
    name: "FightDeckRNRuntime",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "FightDeckRNRuntime", targets: ["FightDeckRNRuntime"]),
    ],
    targets: [
        runtimeTarget,
    ]
)
