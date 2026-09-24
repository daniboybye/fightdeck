package com.fightdeck.rn.runtime

import com.facebook.proguard.annotations.DoNotStrip
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.CxxCallbackImpl
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.UiThreadUtil
import com.facebook.react.bridge.WritableMap
import com.fightdeck.rn.runtime.specs.NativeFightDeckRuntimeBridgeSpec
import java.math.BigDecimal
import java.util.concurrent.ConcurrentHashMap

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

    /** Synchronous, so it runs on the JavaScript thread while the host publishes from main. */
    override fun surfaceLayout(moduleName: String): WritableMap? =
        layouts[moduleName]?.let(Arguments::makeNativeMap)

    /** Only the instance wired to JavaScript gets an emitter, so it is the one layouts go to. */
    @DoNotStrip
    override fun setEventEmitterCallback(eventEmitterCallback: CxxCallbackImpl) {
        super.setEventEmitterCallback(eventEmitterCallback)
        live = this
    }

    private fun emit(layout: Map<String, Any>) {
        emitOnSurfaceLayout(Arguments.makeNativeMap(layout))
    }

    internal companion object {
        private val layouts = ConcurrentHashMap<String, Map<String, Any>>()

        @Volatile
        private var live: FightDeckRuntimeBridgeModule? = null

        /** Stores the layout for `surfaceLayout()` and emits it — unless nothing changed. */
        fun publish(moduleName: String, layout: SurfaceLayout) {
            // Sub-point differences come from layout rounding, not from anything the user sees.
            val map = mapOf(
                "moduleName" to moduleName,
                "safeAreaTop" to Math.round(layout.safeAreaTop).toDouble(),
                "safeAreaBottom" to Math.round(layout.safeAreaBottom).toDouble(),
                "keyboardBottomInset" to Math.round(layout.keyboardBottomInset).toDouble(),
                "chromeBackground" to layout.chromeBackground,
                "textInputActive" to layout.textInputActive,
            )
            if (layouts.put(moduleName, map) != map) {
                live?.emit(map)
            }
        }
    }
}

/** Where the typed calls above end up: one handler per feature, set by its adapter. */
object FeatureResults {
    @Volatile
    var deposit: ((DepositResult) -> Unit)? = null

    @Volatile
    var betslip: ((BetslipResult) -> Unit)? = null
}
