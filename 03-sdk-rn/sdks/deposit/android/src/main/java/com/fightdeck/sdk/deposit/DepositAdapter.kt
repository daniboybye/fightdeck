package com.fightdeck.sdk.deposit

import android.content.Context
import android.os.Bundle
import android.view.View
import com.fightdeck.rn.runtime.DepositResult
import com.fightdeck.rn.runtime.FeatureAdapter
import com.fightdeck.rn.runtime.FeatureResults
import java.math.BigDecimal

/** Data only: the chrome the surface has to clear goes through `FightDeckRNRuntime.publishLayout`. */
data class DepositParams(
    val themeJSON: String,
    val currentBalance: BigDecimal,
)

class DepositAdapter : FeatureAdapter<DepositParams>("DepositFeature") {
    fun createView(context: Context, params: DepositParams, onResult: (DepositResult) -> Unit): View {
        FeatureResults.deposit = onResult
        return createView(context, params)
    }

    override fun propsBundle(params: DepositParams): Bundle =
        Bundle().apply {
            putString("themeJSON", params.themeJSON)
            putString("currentBalance", params.currentBalance.toPlainString())
        }
}
