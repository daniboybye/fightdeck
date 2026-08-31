package com.fightdeck.baseline.ui

import android.view.View
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.union
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalDensity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.fightdeck.rn.runtime.RNSurfaceLayoutMetrics
import com.fightdeck.rn.runtime.RNSurfaceLayoutPush
import com.fightdeck.rn.runtime.RNSurfaceLayoutSnapshot
import com.fightdeck.rn.runtime.SurfaceChrome

/** Default bottom chrome until the RN host view reports a size (tab bar + home indicator). */
private const val DEFAULT_TAB_BAR_CLEARANCE_PX = 168

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
    val imePadding = WindowInsets.ime.union(WindowInsets.navigationBars).asPaddingValues()
    val imeBottomPx = with(density) { imePadding.calculateBottomPadding().roundToPx() }
    var hostView by remember { mutableStateOf<View?>(null) }
    var surfaceHeightPx by remember { mutableIntStateOf(0) }
    var surfaceTopInWindowPx by remember { mutableIntStateOf(0) }
    var layoutStamp by remember { mutableDoubleStateOf(0.0) }

    val windowInsets = hostView?.let { ViewCompat.getRootWindowInsets(it) }
    val systemBars = windowInsets?.getInsets(WindowInsetsCompat.Type.systemBars())
    val topInsetPx = systemBars?.top ?: 0
    val bottomInsetPx = if (includesTabBarClearance) {
        systemBars?.bottom ?: 0
    } else {
        0
    }

    val snapshot = if (hostView != null && surfaceHeightPx > 0) {
        SurfaceChrome.resolve(
            surfaceHeightPx = surfaceHeightPx,
            windowTopInsetPx = topInsetPx,
            windowBottomInsetPx = bottomInsetPx,
            surfaceTopInWindowPx = surfaceTopInWindowPx,
            keyboardOverlapPx = imeBottomPx,
        )
    } else {
        RNSurfaceLayoutSnapshot(
            safeAreaTop = topInsetPx.toFloat(),
            safeAreaBottom = if (includesTabBarClearance) {
                DEFAULT_TAB_BAR_CLEARANCE_PX.toFloat()
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
