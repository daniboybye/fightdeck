package com.fightdeck.rn.runtime

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap

/** JS → native channel. Registered inside the SDK runtime module, never in the host app. */
class FightDeckRuntimeBridgeModule(
    reactContext: ReactApplicationContext,
) : ReactContextBaseJavaModule(reactContext) {

    override fun getName(): String = "FightDeckRuntimeBridge"

    @ReactMethod
    fun postResult(feature: String, payload: ReadableMap) {
        val map = payload.toHashMap()
        FightDeckRuntimeBridgeNotifier.post(feature, map)
    }
}
