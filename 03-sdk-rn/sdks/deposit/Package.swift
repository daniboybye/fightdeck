// swift-tools-version: 6.0
import PackageDescription

let depositTarget: Target = .binaryTarget(
    name: "DepositSDK",
    path: "out/DepositSDK.xcframework"
)

let package = Package(
    name: "DepositSDK",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "DepositSDK", targets: ["DepositSDK"]),
    ],
    targets: [
        depositTarget,
    ]
)
