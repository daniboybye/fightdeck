package com.fightdeck.rn.runtime

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule

/** JS ↔ native channel. Registered inside the SDK runtime module, never in the host app. */
class FightDeckRuntimeBridgeModule(
    reactContext: ReactApplicationContext,
) : ReactContextBaseJavaModule(reactContext) {

    init {
        FightDeckRuntimeBridgeNotifier.bindLayoutEmitter { payload ->
            reactApplicationContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
                .emit("fightdeckSurfaceLayout", payload)
        }
    }

    override fun getName(): String = "FightDeckRuntimeBridge"

    @ReactMethod
    fun postResult(feature: String, payload: ReadableMap) {
        FightDeckRuntimeBridgeNotifier.post(feature, payload.toHashMap())
    }

    // NativeEventEmitter requires these stubs even when events are pushed from native code.
    @ReactMethod
    fun addListener(eventName: String) = Unit

    @ReactMethod
    fun removeListeners(count: Int) = Unit
}
