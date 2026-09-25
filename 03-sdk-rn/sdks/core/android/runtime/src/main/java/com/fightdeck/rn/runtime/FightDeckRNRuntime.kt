package com.fightdeck.rn.runtime

import android.app.Application
import android.content.Context
import android.os.Bundle
import android.util.Log
import android.view.View
import androidx.appcompat.view.ContextThemeWrapper
import com.facebook.react.ReactApplication
import com.facebook.react.ReactHost
import com.facebook.react.interfaces.fabric.ReactSurface
import com.facebook.react.runtime.ReactSurfaceImpl
import com.google.android.material.R

/** Owns the single ReactHost for all SDK features. */
object FightDeckRNRuntime {
    private var coldStartMs: Long = 0
    private var prewarmedStartMs: Long = 0
    private var prewarmed = false

    internal val surfaceTagKey: Int = "com.fightdeck.rn.runtime.ReactSurface".hashCode()

    private fun reactHost(app: Application): ReactHost =
        requireNotNull((app as ReactApplication).reactHost) {
            "ReactHost is not configured on the host Application"
        }

    fun prewarm(app: Application) {
        if (prewarmed) {
            return
        }
        val start = System.nanoTime()
        reactHost(app).start()
        prewarmedStartMs = (System.nanoTime() - start) / 1_000_000
        prewarmed = true
    }

    fun createSurfaceView(
        context: Context,
        moduleName: String,
        initialProps: Bundle,
    ): View {
        val start = System.nanoTime()
        val host = reactHost(context.applicationContext as Application)
        val cold = !prewarmed
        if (cold) {
            host.start()
            prewarmed = true
        }
        val themedContext = ContextThemeWrapper(
            context,
            R.style.Theme_MaterialComponents_DayNight_NoActionBar,
        )
        val surface: ReactSurface = host.createSurface(themedContext, moduleName, initialProps)
        // ReactSurfaceView hands Fabric its size from its own onMeasure, and the AndroidView
        // around it measures it exactly, so starting straight away is enough — the same order
        // ReactDelegate uses for a full-screen React activity.
        surface.start()
        val surfaceView = requireNotNull(surface.view) {
            "ReactSurface did not produce a view for module $moduleName"
        }
        surfaceView.setTag(surfaceTagKey, surface)
        if (cold) {
            // start() only schedules the host, so timing it alone measured almost nothing. This
            // is host start plus surface creation — the synchronous half of a cold start, the
            // same half the iOS runtime times.
            coldStartMs = (System.nanoTime() - start) / 1_000_000
            Log.i("FightDeckStartup", "cold=${coldStartMs}ms")
        }
        return surfaceView
    }

    fun updateSurfaceProps(hostView: View, props: Bundle) {
        val surface = hostView.getTag(surfaceTagKey) as? ReactSurfaceImpl ?: return
        surface.updateInitProps(props)
    }

    fun stopSurface(hostView: View) {
        val surface = hostView.getTag(surfaceTagKey) as? ReactSurface ?: return
        surface.stop()
        hostView.setTag(surfaceTagKey, null)
    }

    fun startupMetrics(): Pair<Long, Long> = coldStartMs to prewarmedStartMs
}
