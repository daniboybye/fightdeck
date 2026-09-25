package com.fightdeck.sdk.fighter

import android.os.Bundle
import com.fightdeck.rn.runtime.FeatureAdapter

data class FighterParams(
    val fighterJSON: String,
    val portraitURL: String,
)

/** The fighter profile reports nothing back: the codegen spec declares no fighter methods. */
class FighterAdapter : FeatureAdapter<FighterParams>("FighterFeature") {
    override fun propsBundle(params: FighterParams): Bundle =
        Bundle().apply {
            putString("fighterJSON", params.fighterJSON)
            putString("portraitURL", params.portraitURL)
        }
}
