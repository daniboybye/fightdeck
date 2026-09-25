package com.fightdeck.swiftcore.bridge

import com.fightdeck.fightcore.FightCoreJava

/**
 * Loads the three cross-compiled Swift SDKs that `swift-java jextract --mode=jni` generated.
 */
object SwiftCoreBridge {
    init {
        System.loadLibrary("fightcore")
        System.loadLibrary("fightslip")
        System.loadLibrary("fightevents")
    }

    fun verifyNativeCore(): String = FightCoreJava.formatCurrency("361.11")
}
