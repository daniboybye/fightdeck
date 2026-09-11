package com.fightdeck.swiftcore.bridge

import com.fightdeck.fightcore.FightCoreJava

/**
 * The Compose host runs the cross-compiled Swift core, reached through the JNI bindings
 * that `swift-java jextract --mode=jni` generated from `Sources/FightCoreJava`.
 *
 * Loading is implicit: every generated class has a static initialiser that calls
 * `System.loadLibrary` for `libSwiftJava.so` and `libfightcore.so`, both shipped in
 * `fightcore.aar`. This object only exists to make that fact assertable at startup.
 */
object SwiftCoreBridge {
    val isStub: Boolean = false

    /** Forces the class initialiser, so a packaging mistake fails here and not mid-screen. */
    fun verifyNativeCore(): String = FightCoreJava.formatCurrency("361.11")
}
