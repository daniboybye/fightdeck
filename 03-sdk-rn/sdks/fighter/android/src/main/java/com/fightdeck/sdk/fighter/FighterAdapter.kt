package com.fightdeck.sdk.fighter

import android.os.Bundle
import com.fightdeck.rn.runtime.FeatureAdapter

/** Data only: the chrome the surface has to clear goes through `FightDeckRNRuntime.publishLayout`. */
data class FighterParams(
    val themeJSON: String,
    val fighterJSON: String,
    val portraitURL: String,
)

/** The fighter profile reports nothing back: the codegen spec declares no fighter methods. */
class FighterAdapter : FeatureAdapter<FighterParams>("FighterFeature") {
    override fun propsBundle(params: FighterParams): Bundle =
        Bundle().apply {
            putString("themeJSON", params.themeJSON)
            putString("fighterJSON", params.fighterJSON)
            putString("portraitURL", params.portraitURL)
        }
}
