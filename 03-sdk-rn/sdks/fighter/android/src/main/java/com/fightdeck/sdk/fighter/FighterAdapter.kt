package com.fightdeck.sdk.fighter

import android.app.Application
import android.content.Context
import android.os.Bundle
import android.view.View
import com.fightdeck.rn.runtime.FightDeckRNRuntime
import com.fightdeck.rn.runtime.FightDeckRuntimeBridgeNotifier
import com.fightdeck.rn.runtime.RNSurfaceLayoutSnapshot
import com.fightdeck.rn.runtime.SurfaceChrome
import com.fightdeck.rn.runtime.applySurfaceLayout

data class FighterParams(
    val themeJSON: String,
    val fighterJSON: String,
    val portraitURL: String,
    val layout: RNSurfaceLayoutSnapshot? = null,
    val layoutStamp: Double = 0.0,
)

sealed class FighterResult {
    data object Cancelled : FighterResult()
}

class FighterAdapter {
    private var configured = false

    fun configure(app: Application) {
        if (configured) {
            return
        }
        FightDeckRNRuntime.configure(app)
        configured = true
    }

    fun createView(
        context: Context,
        app: Application,
        params: FighterParams,
        onResult: (FighterResult) -> Unit = {},
    ): View {
        configure(app)
        FightDeckRuntimeBridgeNotifier.setListener("fighter") { _ ->
            onResult(FighterResult.Cancelled)
        }
        return FightDeckRNRuntime.createSurfaceView(
            context,
            app,
            "FighterFeature",
            propsBundle(params),
        )
    }

    fun updateProps(hostView: View, params: FighterParams) {
        FightDeckRNRuntime.updateSurfaceProps(hostView, propsBundle(params))
    }

    fun propsBundle(params: FighterParams): Bundle =
        Bundle().apply {
            putString("themeJSON", params.themeJSON)
            putString("fighterJSON", params.fighterJSON)
            putString("portraitURL", params.portraitURL)
            val layout = params.layout ?: RNSurfaceLayoutSnapshot(
                safeAreaTop = 0f,
                safeAreaBottom = 0f,
                keyboardBottomInset = 0f,
                chromeBackground = SurfaceChrome.listBackgroundHex(),
            )
            applySurfaceLayout(layout, false, params.layoutStamp)
        }

}
