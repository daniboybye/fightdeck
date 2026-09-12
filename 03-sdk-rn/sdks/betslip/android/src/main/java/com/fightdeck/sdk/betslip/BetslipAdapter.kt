package com.fightdeck.sdk.betslip

import android.app.Application
import android.content.Context
import android.os.Bundle
import android.view.View
import com.fightdeck.rn.runtime.FightDeckRNRuntime
import com.fightdeck.rn.runtime.FightDeckRuntimeBridgeNotifier
import com.fightdeck.rn.runtime.RNSurfaceLayoutSnapshot
import com.fightdeck.rn.runtime.SurfaceChrome
import com.fightdeck.rn.runtime.applySurfaceLayout
import java.math.BigDecimal

data class BetslipParams(
    val themeJSON: String,
    val balance: BigDecimal,
    val slipJSON: String,
    val eventsJSON: String,
    val betPlacedMessage: String = "",
    val layout: RNSurfaceLayoutSnapshot? = null,
    val textInputActive: Boolean = false,
    val layoutStamp: Double = 0.0,
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
        return FightDeckRNRuntime.createSurfaceView(
            context,
            app,
            "BetslipFeature",
            propsBundle(params),
        )
    }

    fun updateProps(hostView: View, params: BetslipParams) {
        FightDeckRNRuntime.updateSurfaceProps(hostView, propsBundle(params))
    }

    fun propsBundle(params: BetslipParams): Bundle =
        Bundle().apply {
            putString("themeJSON", params.themeJSON)
            putString("balance", params.balance.toPlainString())
            putString("slipJSON", params.slipJSON)
            putString("eventsJSON", params.eventsJSON)
            putString("betPlacedMessage", params.betPlacedMessage)
            val layout = params.layout ?: RNSurfaceLayoutSnapshot(
                safeAreaTop = 0f,
                safeAreaBottom = 168f,
                keyboardBottomInset = 0f,
                chromeBackground = SurfaceChrome.listBackgroundHex(),
            )
            applySurfaceLayout(layout, params.textInputActive, params.layoutStamp)
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
