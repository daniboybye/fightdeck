package com.fightdeck.rn.runtime

import android.util.Log
import com.facebook.react.runtime.ReactSurfaceImpl

/**
 * Fabric requires [ReactSurfaceImpl.updateLayoutSpecs] before [com.facebook.react.interfaces.fabric.ReactSurface.start].
 * React Native 0.84 exposes that method as `internal` on [ReactSurfaceImpl] — there is no public
 * layout-spec API on [com.facebook.react.runtime.ReactHost] yet.
 *
 * Version coupling: pinned React Native in repository `versions.lock.toml` (`react_native.version`).
 * Upgrading RN without re-verifying this seam can yield blank SDK surfaces with no compile error.
 */
internal object FabricLayoutSpecsBridge {
    private const val TAG = "FightDeckRNLayout"

    private val method by lazy {
        runCatching {
            ReactSurfaceImpl::class.java.getDeclaredMethod(
                "updateLayoutSpecs\$ReactAndroid",
                Int::class.javaPrimitiveType,
                Int::class.javaPrimitiveType,
                Int::class.javaPrimitiveType,
                Int::class.javaPrimitiveType,
            ).apply { isAccessible = true }
        }.getOrElse { error ->
            Log.e(TAG, "ReactSurfaceImpl.updateLayoutSpecs\$ReactAndroid missing — Fabric surfaces will not mount", error)
            null
        }
    }

    fun push(
        surface: ReactSurfaceImpl,
        widthMeasureSpec: Int,
        heightMeasureSpec: Int,
        offsetX: Int,
        offsetY: Int,
    ) {
        val update = method
            ?: error(
                "FightDeck RN SDK: ReactSurfaceImpl.updateLayoutSpecs unavailable. " +
                    "Pinned react-android may have renamed the method; see FabricLayoutSpecsBridge.",
            )
        update.invoke(surface, widthMeasureSpec, heightMeasureSpec, offsetX, offsetY)
    }
}
