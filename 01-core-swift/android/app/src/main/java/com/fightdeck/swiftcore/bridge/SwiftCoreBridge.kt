package com.fightdeck.swiftcore.bridge

import com.fightdeck.sdk.FightDeckJava

/**
 * Loads the cross-compiled Swift SDKs — FightCore, FightSlip and FightEvents, linked into one
 * library — whose bindings `swift-java jextract --mode=jni` generated.
 */
object SwiftCoreBridge {
    init {
        System.loadLibrary("fightdeck")
    }

    fun verifyNativeCore(): String = FightDeckJava.formatCurrency("361.11")
}
