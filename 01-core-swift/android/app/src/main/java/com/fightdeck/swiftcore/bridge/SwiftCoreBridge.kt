package com.fightdeck.swiftcore.bridge

/**
 * **STUB — NOT THE SWIFT CORE**
 *
 * Android cross-compilation of the Swift FightCore failed on this machine (see
 * `01-core-swift/README.md`). This object exists so the Compose host app builds and
 * demonstrates the UI contract. It delegates to the Kotlin port of FightCore in
 * `com.fightdeck.swiftcore.core`, which mirrors the contract fixtures but is **not**
 * cross-compiled Swift.
 *
 * When `fightcore.aar` from `./build-aar.sh` is available, replace calls here with
 * swift-java generated bindings.
 */
object SwiftCoreBridge {
    val isStub: Boolean = true

    const val STUB_REASON: String =
        "Swift SDK for Android requires the open-source Swift 6.3.3 toolchain; " +
            "Apple Xcode Swift 6.3.3 cannot deserialize the Android Foundation module."
}
