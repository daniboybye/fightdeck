// swift-tools-version: 6.0
import PackageDescription

let buildJavaBridge = Context.environment["FIGHTEVENTS_JAVA_BRIDGE"] == "1"

let package = Package(
    name: "FightEvents",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
    ],
    products: [
        .library(
            name: "FightEvents",
            targets: ["FightEvents"]
        ),
        .library(
            name: "FightEventsShared",
            type: .dynamic,
            targets: buildJavaBridge ? ["FightEvents", "FightEventsJava"] : ["FightEvents"]
        ),
    ],
    dependencies: [
        .package(path: "../core"),
    ] + (buildJavaBridge
        ? [.package(url: "https://github.com/swiftlang/swift-java", exact: "0.6.0")]
        : []),
    targets: [
        .target(
            name: "FightEvents",
            dependencies: [.product(name: "FightCore", package: "core")],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "FightEventsTests",
            dependencies: ["FightEvents"]
        ),
    ] + (buildJavaBridge ? [javaBridgeTarget] : [])
)

var javaBridgeTarget: Target {
    .target(
        name: "FightEventsJava",
        dependencies: [
            "FightEvents",
            .product(name: "SwiftJava", package: "swift-java"),
        ],
        exclude: ["swift-java.config"],
        swiftSettings: [.swiftLanguageMode(.v5)],
        plugins: [.plugin(name: "JExtractSwiftPlugin", package: "swift-java")]
    )
}
