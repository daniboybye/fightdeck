package com.fightdeck.sdk.betslip

import android.content.Context
import android.os.Bundle
import android.view.View
import com.fightdeck.rn.runtime.BetslipResult
import com.fightdeck.rn.runtime.FeatureAdapter
import com.fightdeck.rn.runtime.FeatureResults
import java.math.BigDecimal
import java.math.RoundingMode
import org.json.JSONArray
import org.json.JSONObject

/** One leg of the slip, with enough of its bout for the screen to name it and check it. */
data class BetslipSelection(
    val boutId: String,
    val fighterId: String,
    val opponentId: String,
    val odds: BigDecimal,
    val fighterName: String,
    val opponentName: String,
    val eventName: String,
)

/** Values, not JSON: the adapter compares them structurally and encodes only what it pushes. */
data class BetslipParams(
    val balance: BigDecimal,
    val stake: BigDecimal,
    val selections: List<BetslipSelection>,
    val betPlacedMessage: String = "",
)

class BetslipAdapter : FeatureAdapter<BetslipParams>("BetslipFeature") {
    fun createView(context: Context, params: BetslipParams, onResult: (BetslipResult) -> Unit): View {
        FeatureResults.betslip = onResult
        return createView(context, params)
    }

    override fun propsBundle(params: BetslipParams): Bundle =
        Bundle().apply {
            putString("balance", params.balance.toPlainString())
            putString("slipJSON", slipJSON(params))
            putString("betPlacedMessage", params.betPlacedMessage)
        }

    private fun slipJSON(params: BetslipParams): String =
        JSONObject()
            .put("stake", amount(params.stake))
            .put(
                "selections",
                JSONArray(
                    params.selections.map { leg ->
                        JSONObject()
                            .put("boutId", leg.boutId)
                            .put("fighterId", leg.fighterId)
                            .put("opponentId", leg.opponentId)
                            .put("odds", amount(leg.odds))
                            .put("fighterName", leg.fighterName)
                            .put("opponentName", leg.opponentName)
                            .put("eventName", leg.eventName)
                    },
                ),
            )
            .toString()

    /** Money travels as a plain two-place decimal, the form the screen's parser expects. */
    private fun amount(value: BigDecimal): String = value.setScale(2, RoundingMode.HALF_UP).toPlainString()
}
