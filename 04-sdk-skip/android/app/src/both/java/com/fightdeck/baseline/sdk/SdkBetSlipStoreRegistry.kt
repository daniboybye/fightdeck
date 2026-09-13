package com.fightdeck.baseline.sdk

import android.content.Context
import com.fightdeck.baseline.ui.MainViewModel
import fight.deck.betslip.BetSlipStore
import java.util.WeakHashMap

/**
 * The slip tab leaves composition when another tab is selected; [remember] would tear down
 * the SDK store with it. Pin one store per [MainViewModel] instead, matching iOS @State.
 */
object SdkBetSlipStoreRegistry {
    private val stores = WeakHashMap<MainViewModel, BetSlipStore>()

    fun store(viewModel: MainViewModel, context: Context): BetSlipStore =
        stores.getOrPut(viewModel) {
            BetSlipStore(
                fightCore = SdkFightCoreFactory.build(context.applicationContext),
                slip = viewModel.slip.value,
                balance = viewModel.balance.value,
            )
        }
}
