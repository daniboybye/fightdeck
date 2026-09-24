package com.fightdeck.baseline.ui

import android.content.Context
import android.view.View
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.ime
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.fightdeck.rn.runtime.FightDeckRNRuntime
import com.fightdeck.rn.runtime.SurfaceChrome
import com.fightdeck.rn.runtime.SurfaceLayout

/** Default bottom chrome until the RN host view reports a size (tab bar + home indicator). */
private const val DEFAULT_TAB_BAR_CLEARANCE_DP = 64f

/**
 * Every React Native surface in the app is mounted through this one composable. Data and
 * chrome reach React on different channels: [update] hands the adapter new parameters, and
 * the adapter drops the ones that change nothing, because props re-render the surface from
 * its root and steal text-field focus. The chrome the surface has to clear changes *because*
 * a field gained focus, so it goes out through [FightDeckRNRuntime.publishLayout] instead.
 */
@Composable
fun RNSurface(
    includesTabBarClearance: Boolean,
    create: (Context) -> View,
    update: (View) -> Unit,
    modifier: Modifier = Modifier,
) {
    val trackHost = rememberRNSurfaceLayout(includesTabBarClearance)
    AndroidView(
        modifier = modifier.fillMaxSize(),
        factory = { context -> create(context).also(trackHost) },
        update = { view ->
            trackHost(view)
            update(view)
            view.requestLayout()
        },
        onRelease = FightDeckRNRuntime::stopSurface,
    )
}

@Composable
private fun rememberRNSurfaceLayout(includesTabBarClearance: Boolean): (View) -> Unit {
    val density = LocalDensity.current
    val imeInsetPx = with(density) {
        WindowInsets.ime.asPaddingValues().calculateBottomPadding().roundToPx()
    }
    val windowHeightPx = LocalWindowInfo.current.containerSize.height
    var hostView by remember { mutableStateOf<View?>(null) }
    var surfaceHeightPx by remember { mutableIntStateOf(0) }
    var surfaceTopInWindowPx by remember { mutableIntStateOf(0) }

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

    val layout = if (hostView != null && surfaceHeightPx > 0) {
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
        SurfaceLayout(
            safeAreaTop = with(density) { topInsetPx.toDp().value },
            safeAreaBottom = if (includesTabBarClearance) DEFAULT_TAB_BAR_CLEARANCE_DP else 0f,
        )
    }

    LaunchedEffect(hostView, layout) {
        hostView?.let { FightDeckRNRuntime.publishLayout(it, layout) }
    }

    return { view ->
        if (hostView !== view) {
            hostView = view
            // Before the surface starts, so the first thing React reads is already this.
            FightDeckRNRuntime.publishLayout(view, layout)
            fun publishGeometry() {
                val height = view.height
                if (height <= 0) {
                    return
                }
                surfaceHeightPx = height
                val location = IntArray(2)
                view.getLocationInWindow(location)
                surfaceTopInWindowPx = location[1]
            }
            view.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
                publishGeometry()
            }
            view.post { publishGeometry() }
        }
    }
}

private fun SurfaceLayout.inDensityIndependentUnits(scale: Float) = copy(
    safeAreaTop = safeAreaTop / scale,
    safeAreaBottom = safeAreaBottom / scale,
    keyboardBottomInset = keyboardBottomInset / scale,
)
