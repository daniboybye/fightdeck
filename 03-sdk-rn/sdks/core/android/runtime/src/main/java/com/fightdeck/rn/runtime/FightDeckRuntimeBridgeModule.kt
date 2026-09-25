package com.fightdeck.rn.runtime

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.UiThreadUtil
import com.fightdeck.rn.runtime.specs.NativeFightDeckRuntimeBridgeSpec
import java.math.BigDecimal

/**
 * Implements the base class codegen wrote from `NativeFightDeckRuntimeBridge.ts`. The JNI
 * glue, argument conversion and event plumbing are generated; this class only says where
 * each call lands. Registered by [FightDeckRNRuntimePackage], never in the host app.
 */
class FightDeckRuntimeBridgeModule(
    reactContext: ReactApplicationContext,
) : NativeFightDeckRuntimeBridgeSpec(reactContext) {

    override fun depositConfirmed() = deliver {
        FeatureResults.deposit?.invoke(DepositResult.Confirmed)
    }

    override fun depositCompleted(amount: String) = deliver {
        FeatureResults.deposit?.invoke(DepositResult.Completed(BigDecimal(amount)))
    }

    override fun betslipUpdated(slipJSON: String) = deliver {
        FeatureResults.betslip?.invoke(BetslipResult.Updated(slipJSON))
    }

    override fun betslipBrowseEvents() = deliver {
        FeatureResults.betslip?.invoke(BetslipResult.BrowseEvents)
    }

    override fun betslipDeposit() = deliver {
        FeatureResults.betslip?.invoke(BetslipResult.Deposit)
    }

    override fun betslipPlaced(message: String, slipJSON: String, balance: String) = deliver {
        FeatureResults.betslip?.invoke(BetslipResult.Placed(message, slipJSON, balance))
    }

    /**
     * Module methods arrive on React Native's native-modules thread, and the host answers most
     * results by navigating — which Compose only allows on the main thread. "Add funds" crashed
     * on exactly that. iOS gets the same guarantee from the module's `methodQueue`.
     */
    private fun deliver(result: () -> Unit) {
        UiThreadUtil.runOnUiThread(result)
    }
}

/** Where the typed calls above end up: one handler per feature, set by its adapter. */
object FeatureResults {
    @Volatile
    var deposit: ((DepositResult) -> Unit)? = null

    @Volatile
    var betslip: ((BetslipResult) -> Unit)? = null
}
