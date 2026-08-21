package com.fightdeck.swiftcore.bridge

import android.content.Context
import android.content.SharedPreferences

/**
 * Kotlin implementation of the Swift `PreferencesStore` port declared in FightCore.
 * This is the ports-and-adapters talking point: Swift declares the hole, Kotlin fills it.
 *
 * When swift-java bindings land, this class implements the generated JNI callback interface.
 */
class SharedPreferencesStore(context: Context) : PreferencesStore {
    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override fun read(key: String): String? = prefs.getString(key, null)

    override fun write(key: String, value: String) {
        prefs.edit().putString(key, value).apply()
    }

    companion object {
        private const val PREFS_NAME = "fightdeck_swiftcore"
    }
}

/** Mirrors the Swift `PreferencesStore` protocol until JNI bindings exist. */
interface PreferencesStore {
    fun read(key: String): String?
    fun write(key: String, value: String)
}
