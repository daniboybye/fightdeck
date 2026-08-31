package com.fightdeck.baseline.ui

import com.fightdeck.rn.runtime.RNSurfaceLayoutSnapshot
import kotlin.math.roundToInt

/**
 * Data and chrome travel to React on different channels, so they need separate fingerprints.
 * Data goes through surface props, which re-renders from the root and steals text-field focus;
 * chrome goes through the layout event channel instead.
 *
 * Each feature builds its own data list rather than the fingerprint reaching into the SDK
 * parameter types, because those types only exist in the flavours that link the feature.
 */
internal data class RNSurfacePropsFingerprint(
    val data: List<String>,
    val layout: String,
) {
    constructor(
        data: List<String>,
        layout: RNSurfaceLayoutSnapshot?,
        textInputActive: Boolean,
    ) : this(
        data = data,
        // Sub-point differences come from layout rounding, not from anything the user can see.
        layout = "${layout?.safeAreaTop?.roundToInt() ?: 0}|" +
            "${layout?.safeAreaBottom?.roundToInt() ?: 0}|" +
            "${layout?.keyboardBottomInset?.roundToInt() ?: 0}|" +
            "${layout?.chromeBackground.orEmpty()}|$textInputActive",
    )
}
