package com.fightdeck.sdk.betslip

import android.content.Context
import android.os.Bundle
import android.view.View
import com.fightdeck.rn.runtime.BetslipResult
import com.fightdeck.rn.runtime.FeatureResults
import com.fightdeck.rn.runtime.FightDeckRNRuntime
import java.math.BigDecimal

/** Data only: the chrome the surface has to clear goes through `FightDeckRNRuntime.publishLayout`. */
data class BetslipParams(
    val themeJSON: String,
    val balance: BigDecimal,
    val slipJSON: String,
    val eventsJSON: String,
    val betPlacedMessage: String = "",
)

class BetslipAdapter {
    private var lastPushed: BetslipParams? = null

    fun createView(
        context: Context,
        params: BetslipParams,
        onResult: (BetslipResult) -> Unit = {},
    ): View {
        FeatureResults.betslip = onResult
        lastPushed = params
        return FightDeckRNRuntime.createSurfaceView(context, "BetslipFeature", propsBundle(params))
    }

    /** Only a change reaches React: new props re-render the surface from its root. */
    fun updateProps(hostView: View, params: BetslipParams) {
        if (params == lastPushed) {
            return
        }
        lastPushed = params
        FightDeckRNRuntime.updateSurfaceProps(hostView, propsBundle(params))
    }

    private fun propsBundle(params: BetslipParams): Bundle =
        Bundle().apply {
            putString("themeJSON", params.themeJSON)
            putString("balance", params.balance.toPlainString())
            putString("slipJSON", params.slipJSON)
            putString("eventsJSON", params.eventsJSON)
            putString("betPlacedMessage", params.betPlacedMessage)
        }
}
