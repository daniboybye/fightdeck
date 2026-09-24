package com.fightdeck.rn.runtime

/** The host chrome a surface has to clear, in dp — `SurfaceLayout` in the TypeScript spec. */
data class SurfaceLayout(
    val safeAreaTop: Float = 0f,
    val safeAreaBottom: Float = 0f,
    val keyboardBottomInset: Float = 0f,
    val chromeBackground: String = SurfaceChrome.listBackgroundHex(),
    val textInputActive: Boolean = false,
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
    ): SurfaceLayout {
        val windowBottom = surfaceTopInWindowPx + surfaceHeightPx
        val safeBottom = (windowBottom - windowBottomInsetPx).coerceAtLeast(surfaceTopInWindowPx)
        val chromeBottom = (windowBottom - safeBottom).coerceAtLeast(0)
        val keyboardInset = if (keyboardOverlapPx > 120) {
            keyboardOverlapPx.coerceAtMost(surfaceHeightPx)
        } else {
            0
        }
        return SurfaceLayout(
            safeAreaTop = windowTopInsetPx.coerceAtLeast(0).toFloat(),
            safeAreaBottom = chromeBottom.toFloat(),
            keyboardBottomInset = keyboardInset.toFloat(),
        )
    }
}
