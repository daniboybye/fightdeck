// swift-tools-version: 6.0
import PackageDescription

let buildJavaBridge = Context.environment["FIGHTSLIP_JAVA_BRIDGE"] == "1"

let package = Package(
    name: "FightSlip",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
    ],
    products: [
        .library(
            name: "FightSlip",
            targets: ["FightSlip"]
        ),
        .library(
            name: "FightSlipShared",
            type: .dynamic,
            targets: buildJavaBridge ? ["FightSlip", "FightSlipJava"] : ["FightSlip"]
        ),
    ],
    dependencies: [
        .package(path: "../core"),
    ] + (buildJavaBridge
        ? [.package(url: "https://github.com/swiftlang/swift-java", exact: "0.6.0")]
        : []),
    targets: [
        .target(
            name: "FightSlip",
            dependencies: [.product(name: "FightCore", package: "core")],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "FightSlipTests",
            dependencies: ["FightSlip"]
        ),
    ] + (buildJavaBridge ? [javaBridgeTarget] : [])
)

var javaBridgeTarget: Target {
    .target(
        name: "FightSlipJava",
        dependencies: [
            "FightSlip",
            .product(name: "SwiftJava", package: "swift-java"),
        ],
        exclude: ["swift-java.config"],
        swiftSettings: [.swiftLanguageMode(.v5)],
        plugins: [.plugin(name: "JExtractSwiftPlugin", package: "swift-java")]
    )
}
