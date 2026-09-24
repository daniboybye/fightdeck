package com.fightdeck.sdk.deposit

import android.content.Context
import android.os.Bundle
import android.view.View
import com.fightdeck.rn.runtime.DepositResult
import com.fightdeck.rn.runtime.FeatureResults
import com.fightdeck.rn.runtime.FightDeckRNRuntime
import java.math.BigDecimal

/** Data only: the chrome the surface has to clear goes through `FightDeckRNRuntime.publishLayout`. */
data class DepositParams(
    val themeJSON: String,
    val currentBalance: BigDecimal,
)

class DepositAdapter {
    private var lastPushed: DepositParams? = null

    fun createView(
        context: Context,
        params: DepositParams,
        onResult: (DepositResult) -> Unit = {},
    ): View {
        FeatureResults.deposit = onResult
        lastPushed = params
        return FightDeckRNRuntime.createSurfaceView(context, "DepositFeature", propsBundle(params))
    }

    /** Only a change reaches React: new props re-render the surface from its root. */
    fun updateProps(hostView: View, params: DepositParams) {
        if (params == lastPushed) {
            return
        }
        lastPushed = params
        FightDeckRNRuntime.updateSurfaceProps(hostView, propsBundle(params))
    }

    private fun propsBundle(params: DepositParams): Bundle =
        Bundle().apply {
            putString("themeJSON", params.themeJSON)
            putString("currentBalance", params.currentBalance.toPlainString())
        }
}
