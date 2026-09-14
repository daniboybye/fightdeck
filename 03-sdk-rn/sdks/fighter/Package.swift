// swift-tools-version: 6.0
import PackageDescription

let fighterTarget: Target = .binaryTarget(
    name: "FighterSDK",
    path: "out/FighterSDK.xcframework"
)

let package = Package(
    name: "FighterSDK",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "FighterSDK", targets: ["FighterSDK"]),
    ],
    targets: [
        fighterTarget,
    ]
)
