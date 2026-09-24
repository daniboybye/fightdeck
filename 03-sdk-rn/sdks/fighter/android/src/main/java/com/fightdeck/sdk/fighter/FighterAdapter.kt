package com.fightdeck.sdk.fighter

import android.content.Context
import android.os.Bundle
import android.view.View
import com.fightdeck.rn.runtime.FightDeckRNRuntime

/** Data only: the chrome the surface has to clear goes through `FightDeckRNRuntime.publishLayout`. */
data class FighterParams(
    val themeJSON: String,
    val fighterJSON: String,
    val portraitURL: String,
)

/** The fighter profile reports nothing back: the codegen spec declares no fighter methods. */
class FighterAdapter {
    private var lastPushed: FighterParams? = null

    fun createView(context: Context, params: FighterParams): View {
        lastPushed = params
        return FightDeckRNRuntime.createSurfaceView(context, "FighterFeature", propsBundle(params))
    }

    /** Only a change reaches React: new props re-render the surface from its root. */
    fun updateProps(hostView: View, params: FighterParams) {
        if (params == lastPushed) {
            return
        }
        lastPushed = params
        FightDeckRNRuntime.updateSurfaceProps(hostView, propsBundle(params))
    }

    private fun propsBundle(params: FighterParams): Bundle =
        Bundle().apply {
            putString("themeJSON", params.themeJSON)
            putString("fighterJSON", params.fighterJSON)
            putString("portraitURL", params.portraitURL)
        }
}
