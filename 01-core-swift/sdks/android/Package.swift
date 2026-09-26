// swift-tools-version: 6.0
import PackageDescription

// Android only. FightCore, FightSlip and FightEvents stay three packages, and iOS links them as
// three; on Android they ship as one shared object. Three `.so` files meant three statically
// linked copies of FightCore, and three Swift images that could not hand each other a Swift
// value — the bout index used to cross from the catalogue to the slip as JSON, through Kotlin.
// Here the three facades are one module, so it crosses as an argument.
//
// Apple builds never resolve this package: jextract runs SwiftSyntax over the sources at build
// time, which costs minutes, and the JNI runtime has no meaning on iOS.
let package = Package(
    name: "FightDeckAndroid",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
    ],
    products: [
        // Android loads code as a shared object, and SwiftPM only emits one for a product
        // declared dynamic.
        .library(
            name: "FightDeckShared",
            type: .dynamic,
            targets: ["FightDeckJava"]
        ),
    ],
    dependencies: [
        .package(path: "../core"),
        .package(path: "../slip"),
        .package(path: "../events"),
        .package(url: "https://github.com/swiftlang/swift-java", exact: "0.6.0"),
    ],
    targets: [
        // Values cross as strings, arrays and tuples because jextract has no mapping for
        // Decimal; see README for what that costs. Language mode v5 matches what the
        // swift-java samples extract cleanly — the generated thunks are not Sendable-audited.
        .target(
            name: "FightDeckJava",
            dependencies: [
                .product(name: "FightCore", package: "core"),
                .product(name: "FightSlip", package: "slip"),
                .product(name: "FightEvents", package: "events"),
                .product(name: "SwiftJava", package: "swift-java"),
            ],
            exclude: ["swift-java.config"],
            swiftSettings: [.swiftLanguageMode(.v5)],
            plugins: [.plugin(name: "JExtractSwiftPlugin", package: "swift-java")]
        ),
    ]
)
