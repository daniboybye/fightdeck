package com.fightdeck.rn.runtime

import com.facebook.react.bridge.WritableMap

/** Host-side notification bus — mirrors iOS NotificationCenter bridge. */
object FightDeckRuntimeBridgeNotifier {
    private val listeners = mutableMapOf<String, (Map<String, Any?>) -> Unit>()
    private var layoutEmitter: ((WritableMap) -> Unit)? = null

    fun bindLayoutEmitter(emitter: (WritableMap) -> Unit) {
        layoutEmitter = emitter
    }

    fun setListener(feature: String, handler: (Map<String, Any?>) -> Unit) {
        listeners[feature] = handler
    }

    fun removeListener(feature: String) {
        listeners.remove(feature)
    }

    fun post(feature: String, payload: Map<String, Any?>) {
        listeners[feature]?.invoke(payload)
    }

    fun emitLayout(payload: WritableMap) {
        layoutEmitter?.invoke(payload)
    }
}
