// swift-tools-version: 6.0
import PackageDescription

let useLocal = Context.environment["FIGHTDECK_LOCAL_SDK"] == "1"
let useReleasePath = Context.environment["FIGHTDECK_RELEASE_PATH"] == "1"
let sdkVersion = "0.1.0"
let releaseBase = Context.environment["FIGHTDECK_RELEASE_BASE_URL"]
    ?? "https://github.com/fightdeck/fightdeck/releases/download/sdk-v\(sdkVersion)"
// Printed by release-sdk.yml for the published zip; see the note in core/Package.swift.
let releaseChecksum = "59886ac5adf16c918d7c9c0ec94d15fd2c81b916eaf2531090877dc8213b5b91"

let rustLibrary: Target = useLocal
    ? .binaryTarget(
        name: "FightEventsRust",
        path: "out/FightEvents.xcframework"
    )
    : useReleasePath
        ? .binaryTarget(
            name: "FightEventsRust",
            path: "out/FightEvents.xcframework.zip"
        )
        : .binaryTarget(
            name: "FightEventsRust",
            url: "\(releaseBase)/FightEvents.xcframework.zip",
            checksum: releaseChecksum
        )

let package = Package(
    name: "FightEvents",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "FightEvents", targets: ["FightEvents"]),
    ],
    targets: [
        rustLibrary,
        .target(
            name: "fighteventsFFI",
            dependencies: ["FightEventsRust"]
        ),
        .target(
            name: "FightEvents",
            dependencies: ["fighteventsFFI"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
