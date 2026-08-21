package com.fightdeck.rn.runtime

/** Host-side notification bus — mirrors iOS NotificationCenter bridge. */
object FightDeckRuntimeBridgeNotifier {
    private val listeners = mutableMapOf<String, (Map<String, Any?>) -> Unit>()

    fun setListener(feature: String, handler: (Map<String, Any?>) -> Unit) {
        listeners[feature] = handler
    }

    fun removeListener(feature: String) {
        listeners.remove(feature)
    }

    fun post(feature: String, payload: Map<String, Any?>) {
        listeners[feature]?.invoke(payload)
    }
}
