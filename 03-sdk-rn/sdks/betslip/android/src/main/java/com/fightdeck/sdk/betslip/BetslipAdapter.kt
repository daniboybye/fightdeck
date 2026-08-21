package com.fightdeck.sdk.betslip

import android.app.Application
import android.content.Context
import android.os.Bundle
import android.view.View
import com.fightdeck.rn.runtime.FightDeckRNRuntime
import com.fightdeck.rn.runtime.FightDeckRuntimeBridgeNotifier
import java.math.BigDecimal

data class BetslipParams(
    val accessToken: String,
    val environment: String,
    val locale: String,
    val themeJSON: String,
    val balance: BigDecimal,
    val slipJSON: String,
    val eventsJSON: String,
)

sealed class BetslipResult {
    data class Updated(val slipJSON: String) : BetslipResult()
    data object BrowseEvents : BetslipResult()
    data object Deposit : BetslipResult()
    data class Placed(val message: String, val slipJSON: String, val balance: String) : BetslipResult()
    data object Cancelled : BetslipResult()
}

class BetslipAdapter {
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
        params: BetslipParams,
        onResult: (BetslipResult) -> Unit = {},
    ): View {
        configure(app)
        FightDeckRuntimeBridgeNotifier.setListener("betslip") { payload ->
            onResult(mapResult(payload))
        }
        val props = Bundle().apply {
            putString("accessToken", params.accessToken)
            putString("environment", params.environment)
            putString("locale", params.locale)
            putString("themeJSON", params.themeJSON)
            putString("balance", params.balance.toPlainString())
            putString("slipJSON", params.slipJSON)
            putString("eventsJSON", params.eventsJSON)
        }
        return FightDeckRNRuntime.createSurfaceView(context, app, "BetslipFeature", props)
    }

    private fun mapResult(payload: Map<String, Any?>): BetslipResult =
        when (payload["type"]) {
            "updated" -> BetslipResult.Updated(payload["slipJSON"] as? String ?: "{}")
            "browse" -> BetslipResult.BrowseEvents
            "deposit" -> BetslipResult.Deposit
            "placed" -> BetslipResult.Placed(
                message = payload["message"] as? String ?: "",
                slipJSON = payload["slipJSON"] as? String ?: "{}",
                balance = payload["balance"] as? String ?: "0",
            )
            else -> BetslipResult.Cancelled
        }
}
