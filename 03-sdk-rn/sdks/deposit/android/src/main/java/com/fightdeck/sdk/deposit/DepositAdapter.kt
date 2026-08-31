package com.fightdeck.sdk.deposit

import android.app.Application
import android.content.Context
import android.os.Bundle
import android.view.View
import com.fightdeck.rn.runtime.FightDeckRNRuntime
import com.fightdeck.rn.runtime.FightDeckRuntimeBridgeNotifier
import com.fightdeck.rn.runtime.RNSurfaceLayoutSnapshot
import com.fightdeck.rn.runtime.applySurfaceLayout
import java.math.BigDecimal

data class DepositParams(
    val accessToken: String,
    val environment: String,
    val locale: String,
    val themeJSON: String,
    val currentBalance: BigDecimal,
    val layout: RNSurfaceLayoutSnapshot? = null,
    val textInputActive: Boolean = false,
    val layoutStamp: Double = 0.0,
)

sealed class DepositResult {
    data object Confirmed : DepositResult()
    data class Completed(val amount: BigDecimal) : DepositResult()
    data object Cancelled : DepositResult()
    data class Failed(val reason: String) : DepositResult()
}

interface DepositHosting {
    fun configure(app: Application)
    fun createView(
        context: Context,
        app: Application,
        params: DepositParams,
        onResult: (DepositResult) -> Unit = {},
    ): View
}

class DepositAdapter : DepositHosting {
    private var configured = false

    override fun configure(app: Application) {
        if (configured) {
            return
        }
        FightDeckRNRuntime.configure(app)
        configured = true
    }

    override fun createView(
        context: Context,
        app: Application,
        params: DepositParams,
        onResult: (DepositResult) -> Unit,
    ): View {
        configure(app)
        FightDeckRuntimeBridgeNotifier.setListener("deposit") { payload ->
            onResult(mapResult(payload))
        }
        return FightDeckRNRuntime.createSurfaceView(
            context,
            app,
            "DepositFeature",
            propsBundle(params),
        )
    }

    fun updateProps(hostView: View, params: DepositParams) {
        FightDeckRNRuntime.updateSurfaceProps(hostView, propsBundle(params))
    }

    fun propsBundle(params: DepositParams): Bundle =
        Bundle().apply {
            putString("accessToken", params.accessToken)
            putString("environment", params.environment)
            putString("locale", params.locale)
            putString("themeJSON", params.themeJSON)
            putString("currentBalance", params.currentBalance.toPlainString())
            params.layout?.let { layout ->
                applySurfaceLayout(layout, params.textInputActive, params.layoutStamp)
            }
        }

    private fun mapResult(payload: Map<String, Any?>): DepositResult =
        when (payload["type"]) {
            "confirmed" -> DepositResult.Confirmed
            "completed" -> {
                val raw = (payload["amount"] as? String)?.replace("€", "")?.trim() ?: "0"
                DepositResult.Completed(BigDecimal(raw.ifBlank { "0" }))
            }
            "failed" -> DepositResult.Failed(payload["reason"] as? String ?: "unknown")
            else -> DepositResult.Cancelled
        }
}
