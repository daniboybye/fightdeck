package com.fightdeck.rn.runtime

import android.os.Bundle
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap

/** Mirrors iOS [RNSurfaceLayoutMetrics] — chrome the RN surface must clear below its root. */
data class RNSurfaceLayoutMetrics(
    val safeAreaTop: Float = 0f,
    val safeAreaBottom: Float = 0f,
    val keyboardBottomInset: Float = 0f,
    val chromeBackground: String = SurfaceChrome.listBackgroundHex(),
    val textInputActive: Boolean = false,
)

data class RNSurfaceLayoutSnapshot(
    val safeAreaTop: Float,
    val safeAreaBottom: Float,
    val keyboardBottomInset: Float,
    val chromeBackground: String,
)

object SurfaceChrome {
    /** Matches the host app background token so RN chrome blends with Compose navigation. */
    fun listBackgroundHex(): String = "#0B0E14"

    fun resolve(
        surfaceHeightPx: Int,
        windowTopInsetPx: Int,
        windowBottomInsetPx: Int,
        surfaceTopInWindowPx: Int,
        keyboardOverlapPx: Int,
    ): RNSurfaceLayoutSnapshot {
        val windowBottom = surfaceTopInWindowPx + surfaceHeightPx
        val safeBottom = (windowBottom - windowBottomInsetPx).coerceAtLeast(surfaceTopInWindowPx)
        val chromeBottom = (windowBottom - safeBottom).coerceAtLeast(0)
        val keyboardInset = if (keyboardOverlapPx > 120) {
            keyboardOverlapPx.coerceAtMost(surfaceHeightPx)
        } else {
            0
        }
        return RNSurfaceLayoutSnapshot(
            safeAreaTop = windowTopInsetPx.coerceAtLeast(0).toFloat(),
            safeAreaBottom = chromeBottom.toFloat(),
            keyboardBottomInset = keyboardInset.toFloat(),
            chromeBackground = listBackgroundHex(),
        )
    }
}

object RNSurfaceLayoutPush {
    fun deliver(
        moduleName: String,
        layout: RNSurfaceLayoutSnapshot,
        textInputActive: Boolean,
        layoutStamp: Double,
    ) {
        val payload = Arguments.createMap().apply {
            putString("moduleName", moduleName)
            putDouble("safeAreaTop", layout.safeAreaTop.toDouble())
            putDouble("safeAreaBottom", layout.safeAreaBottom.toDouble())
            putDouble("keyboardBottomInset", layout.keyboardBottomInset.toDouble())
            putString("chromeBackground", layout.chromeBackground)
            putBoolean("textInputActive", textInputActive)
            putDouble("layoutStamp", layoutStamp)
        }
        FightDeckRuntimeBridgeNotifier.emitLayout(payload)
    }
}

fun Bundle.applySurfaceLayout(layout: RNSurfaceLayoutSnapshot, textInputActive: Boolean, layoutStamp: Double) {
    putDouble("safeAreaTop", layout.safeAreaTop.toDouble())
    putDouble("safeAreaBottom", layout.safeAreaBottom.toDouble())
    putDouble("keyboardBottomInset", layout.keyboardBottomInset.toDouble())
    putString("chromeBackground", layout.chromeBackground)
    putBoolean("textInputActive", textInputActive)
    putDouble("layoutStamp", layoutStamp)
}

fun RNSurfaceLayoutMetrics.toSnapshot(): RNSurfaceLayoutSnapshot =
    RNSurfaceLayoutSnapshot(
        safeAreaTop = safeAreaTop,
        safeAreaBottom = safeAreaBottom,
        keyboardBottomInset = keyboardBottomInset,
        chromeBackground = chromeBackground,
    )
