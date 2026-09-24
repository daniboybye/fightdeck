package com.fightdeck.sdk.betslip

import android.content.Context
import android.os.Bundle
import android.view.View
import com.fightdeck.rn.runtime.BetslipResult
import com.fightdeck.rn.runtime.FeatureAdapter
import com.fightdeck.rn.runtime.FeatureResults
import java.math.BigDecimal

/** Data only: the chrome the surface has to clear goes through `FightDeckRNRuntime.publishLayout`. */
data class BetslipParams(
    val themeJSON: String,
    val balance: BigDecimal,
    val slipJSON: String,
    val eventsJSON: String,
    val betPlacedMessage: String = "",
)

class BetslipAdapter : FeatureAdapter<BetslipParams>("BetslipFeature") {
    fun createView(context: Context, params: BetslipParams, onResult: (BetslipResult) -> Unit): View {
        FeatureResults.betslip = onResult
        return createView(context, params)
    }

    override fun propsBundle(params: BetslipParams): Bundle =
        Bundle().apply {
            putString("themeJSON", params.themeJSON)
            putString("balance", params.balance.toPlainString())
            putString("slipJSON", params.slipJSON)
            putString("eventsJSON", params.eventsJSON)
            putString("betPlacedMessage", params.betPlacedMessage)
        }
}
