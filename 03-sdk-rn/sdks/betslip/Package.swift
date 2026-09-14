// swift-tools-version: 6.0
import PackageDescription

let betslipTarget: Target = .binaryTarget(
    name: "BetslipSDK",
    path: "out/BetslipSDK.xcframework"
)

let package = Package(
    name: "BetslipSDK",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "BetslipSDK", targets: ["BetslipSDK"]),
    ],
    targets: [
        betslipTarget,
    ]
)
