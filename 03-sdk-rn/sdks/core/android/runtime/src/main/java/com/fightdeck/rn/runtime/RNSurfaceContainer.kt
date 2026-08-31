package com.fightdeck.rn.runtime

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import com.facebook.react.interfaces.fabric.ReactSurface
import com.facebook.react.runtime.ReactSurfaceImpl
import com.facebook.react.runtime.ReactSurfaceView

/**
 * Wraps a bridgeless [ReactSurfaceView] so it always receives EXACTLY measure specs from the host,
 * pushes layout constraints to Fabric before [ReactSurface.start], and starts only after attach
 * and non-zero layout.
 *
 * Fabric mounts nothing when [ReactSurfaceImpl.updateLayoutSpecs] never receives EXACTLY
 * dimensions before [ReactSurface.start]. See [FabricLayoutSpecsBridge].
 * [AndroidView] before the first meaningful measure pass; ModalBottomSheet usually measures first.
 */
internal class RNSurfaceContainer(
    context: Context,
    private val surface: ReactSurface,
) : FrameLayout(context) {
    private val surfaceImpl = surface as ReactSurfaceImpl
    private var started = false

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        post { maybeStartSurface() }
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val width = View.MeasureSpec.getSize(widthMeasureSpec)
        val height = View.MeasureSpec.getSize(heightMeasureSpec)
        val widthSpec = View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY)
        val heightSpec = View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
        if (childCount > 0) {
            getChildAt(0).measure(widthSpec, heightSpec)
        }
        setMeasuredDimension(width, height)
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        val width = right - left
        val height = bottom - top
        layoutSurfaceChild(width, height)
        pushLayoutSpecs(width, height)
        maybeStartSurface()
    }

    override fun onSizeChanged(width: Int, height: Int, oldWidth: Int, oldHeight: Int) {
        super.onSizeChanged(width, height, oldWidth, oldHeight)
        if (width > 0 && height > 0) {
            pushLayoutSpecs(width, height)
        }
    }

    private fun layoutSurfaceChild(width: Int, height: Int) {
        if (childCount > 0) {
            getChildAt(0).layout(0, 0, width, height)
        }
    }

    /** Mirrors [ReactSurfaceView.onMeasure] — internal to ReactAndroid, required before Fabric paints. */
    private fun pushLayoutSpecs(width: Int, height: Int) {
        if (width <= 0 || height <= 0) {
            return
        }
        val widthSpec = View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY)
        val heightSpec = View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
        val location = IntArray(2)
        getLocationInWindow(location)
        FabricLayoutSpecsBridge.push(surfaceImpl, widthSpec, heightSpec, location[0], location[1])
    }

    private fun maybeStartSurface() {
        if (started || width <= 0 || height <= 0 || !isAttachedToWindow) {
            return
        }
        val widthSpec = View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY)
        val heightSpec = View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
        if (childCount > 0) {
            val child = getChildAt(0)
            child.measure(widthSpec, heightSpec)
            child.layout(0, 0, width, height)
        }
        pushLayoutSpecs(width, height)
        started = true
        surface.start()
        post {
            pushLayoutSpecs(width, height)
            requestLayout()
        }
    }
}
