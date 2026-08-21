package com.fightdeck.rn.runtime

import android.app.Application
import android.content.Context
import android.os.Bundle
import android.view.View
import androidx.appcompat.view.ContextThemeWrapper
import com.facebook.react.ReactApplication
import com.facebook.react.ReactHost
import com.facebook.react.interfaces.fabric.ReactSurface
import com.google.android.material.R

/** Owns the single ReactHost for all SDK features. */
object FightDeckRNRuntime {
    private var configured = false
    private var coldStartMs: Long = 0
    private var prewarmedStartMs: Long = 0
    private var prewarmed = false

    private fun reactHost(app: Application): ReactHost =
        requireNotNull((app as ReactApplication).reactHost) {
            "ReactHost is not configured on the host Application"
        }

    fun configure(app: Application) {
        if (configured) {
            return
        }
        configured = true
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
        app: Application,
        moduleName: String,
        initialProps: Bundle,
    ): View {
        val start = System.nanoTime()
        val host = reactHost(app)
        if (!prewarmed) {
            host.start()
            coldStartMs = (System.nanoTime() - start) / 1_000_000
        }
        val themedContext = ContextThemeWrapper(
            context,
            R.style.Theme_MaterialComponents_DayNight_NoActionBar,
        )
        val surface: ReactSurface = host.createSurface(themedContext, moduleName, initialProps)
        surface.start()
        return requireNotNull(surface.view) {
            "ReactSurface did not produce a view for module $moduleName"
        }
    }

    fun startupMetrics(): Pair<Long, Long> = coldStartMs to prewarmedStartMs
}
