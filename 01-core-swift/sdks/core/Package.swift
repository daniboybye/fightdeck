// swift-tools-version: 6.0
import PackageDescription

// The Java bridge is only built when asked for. Apple builds must not drag in swift-java:
// jextract runs SwiftSyntax over the sources at build time, which costs minutes, and the
// JNI runtime has no meaning on iOS.
let buildJavaBridge = Context.environment["FIGHTCORE_JAVA_BRIDGE"] == "1"

let package = Package(
    name: "FightCore",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
    ],
    products: [
        .library(
            name: "FightCore",
            targets: ["FightCore"]
        ),
        // Android loads code as a shared object, and SwiftPM only emits one for a product
        // declared dynamic. Apple builds keep using the static product above, which is
        // what the xcframework is assembled from.
        .library(
            name: "FightCoreShared",
            type: .dynamic,
            targets: buildJavaBridge ? ["FightCore", "FightCoreJava"] : ["FightCore"]
        ),
    ],
    dependencies: buildJavaBridge
        ? [.package(url: "https://github.com/swiftlang/swift-java", exact: "0.6.0")]
        : [],
    targets: [
        .target(
            name: "FightCore",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "FightCoreTests",
            dependencies: ["FightCore"]
        ),
    ] + (buildJavaBridge ? [javaBridgeTarget] : [])
)

// Values cross this boundary as strings and arrays because jextract has no mapping for
// Decimal; see README for what that costs. Language mode v5 matches what the swift-java
// samples extract cleanly — the generated thunks are not Sendable-audited.
var javaBridgeTarget: Target {
    .target(
        name: "FightCoreJava",
        dependencies: [
            "FightCore",
            .product(name: "SwiftJava", package: "swift-java"),
        ],
        exclude: ["swift-java.config"],
        swiftSettings: [.swiftLanguageMode(.v5)],
        plugins: [.plugin(name: "JExtractSwiftPlugin", package: "swift-java")]
    )
}
