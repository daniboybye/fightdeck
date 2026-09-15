package com.fightdeck.baseline.ui

import android.view.View
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.ime
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.fightdeck.rn.runtime.RNSurfaceLayoutMetrics
import com.fightdeck.rn.runtime.RNSurfaceLayoutPush
import com.fightdeck.rn.runtime.RNSurfaceLayoutSnapshot
import com.fightdeck.rn.runtime.SurfaceChrome

/** Default bottom chrome until the RN host view reports a size (tab bar + home indicator). */
private const val DEFAULT_TAB_BAR_CLEARANCE_DP = 64f

class RNSurfaceLayoutHandle internal constructor(
    internal val metrics: RNSurfaceLayoutMetrics,
    private val onViewChanged: (View) -> Unit,
) {
    fun trackHost(view: View) {
        onViewChanged(view)
    }
}

@Composable
fun rememberRNSurfaceLayout(
    moduleName: String,
    includesTabBarClearance: Boolean,
    textInputActive: Boolean = false,
): RNSurfaceLayoutHandle {
    val density = LocalDensity.current
    val imeInsetPx = with(density) {
        WindowInsets.ime.asPaddingValues().calculateBottomPadding().roundToPx()
    }
    val windowHeightPx = LocalWindowInfo.current.containerSize.height
    var hostView by remember { mutableStateOf<View?>(null) }
    var surfaceHeightPx by remember { mutableIntStateOf(0) }
    var surfaceTopInWindowPx by remember { mutableIntStateOf(0) }
    var layoutStamp by remember { mutableDoubleStateOf(0.0) }

    val windowInsets = hostView?.let { ViewCompat.getRootWindowInsets(it) }
    val systemBars = windowInsets?.getInsets(WindowInsetsCompat.Type.systemBars())
    val topInsetPx = systemBars?.top ?: 0
    // Window insets are measured from the window edge, but the surface usually stops short of it
    // — the tab bar sits below the slip screen. Only the slice that actually reaches the surface
    // is chrome the RN bar has to clear; sending the whole inset lifts the bar twice.
    val surfaceBottomPx = surfaceTopInWindowPx + surfaceHeightPx
    fun overlapWithSurface(insetPx: Int): Int =
        if (insetPx <= 0 || windowHeightPx <= 0) {
            0
        } else {
            (surfaceBottomPx - (windowHeightPx - insetPx)).coerceAtLeast(0)
        }

    val bottomInsetPx = if (includesTabBarClearance) {
        overlapWithSurface(systemBars?.bottom ?: 0)
    } else {
        0
    }

    val snapshot = if (hostView != null && surfaceHeightPx > 0) {
        // React Native lays out in density-independent units, the same as the points the iOS
        // host sends. Window insets come in raw pixels, so they are scaled here rather than
        // arriving as numbers three times too big for the style they end up in.
        SurfaceChrome.resolve(
            surfaceHeightPx = surfaceHeightPx,
            windowTopInsetPx = topInsetPx,
            windowBottomInsetPx = bottomInsetPx,
            surfaceTopInWindowPx = surfaceTopInWindowPx,
            keyboardOverlapPx = overlapWithSurface(imeInsetPx),
        ).inDensityIndependentUnits(density.density)
    } else {
        RNSurfaceLayoutSnapshot(
            safeAreaTop = with(density) { topInsetPx.toDp().value },
            safeAreaBottom = if (includesTabBarClearance) {
                DEFAULT_TAB_BAR_CLEARANCE_DP
            } else {
                0f
            },
            keyboardBottomInset = 0f,
            chromeBackground = SurfaceChrome.listBackgroundHex(),
        )
    }

    LaunchedEffect(hostView, snapshot, textInputActive, layoutStamp) {
        RNSurfaceLayoutPush.deliver(
            moduleName = moduleName,
            layout = snapshot,
            textInputActive = textInputActive,
            layoutStamp = layoutStamp,
        )
    }

    val metrics = RNSurfaceLayoutMetrics(
        safeAreaTop = snapshot.safeAreaTop,
        safeAreaBottom = snapshot.safeAreaBottom,
        keyboardBottomInset = snapshot.keyboardBottomInset,
        chromeBackground = snapshot.chromeBackground,
        textInputActive = textInputActive,
    )

    return RNSurfaceLayoutHandle(metrics) { view ->
        if (hostView === view) {
            return@RNSurfaceLayoutHandle
        }
        hostView = view
        fun publishGeometry() {
            val height = view.height
            if (height <= 0) {
                return
            }
            surfaceHeightPx = height
            val location = IntArray(2)
            view.getLocationInWindow(location)
            surfaceTopInWindowPx = location[1]
            layoutStamp += 1.0
        }
        view.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
            publishGeometry()
        }
        view.post { publishGeometry() }
    }
}

private fun RNSurfaceLayoutSnapshot.inDensityIndependentUnits(scale: Float) = copy(
    safeAreaTop = safeAreaTop / scale,
    safeAreaBottom = safeAreaBottom / scale,
    keyboardBottomInset = keyboardBottomInset / scale,
)
