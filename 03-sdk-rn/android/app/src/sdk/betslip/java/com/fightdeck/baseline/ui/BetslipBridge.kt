package com.fightdeck.baseline.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import com.fightdeck.rn.runtime.BetslipResult
import com.fightdeck.sdk.betslip.BetslipAdapter
import com.fightdeck.sdk.betslip.BetslipParams
import java.math.BigDecimal

@Composable
fun RNBetslipScreen(
    balance: BigDecimal,
    slipJSON: String,
    eventsJSON: String,
    betPlacedMessage: String,
    onBrowseEvents: () -> Unit,
    onDeposit: () -> Unit,
    onUpdated: (String) -> Unit,
    onPlaced: (String, String, String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val adapter = remember { BetslipAdapter() }
    val params = BetslipParams(
        balance = balance,
        slipJSON = slipJSON,
        eventsJSON = eventsJSON,
        betPlacedMessage = betPlacedMessage,
    )
    RNSurface(
        includesTabBarClearance = true,
        create = { context ->
            adapter.createView(context, params) { result ->
                when (result) {
                    is BetslipResult.Updated -> onUpdated(result.slipJSON)
                    BetslipResult.BrowseEvents -> onBrowseEvents()
                    BetslipResult.Deposit -> onDeposit()
                    is BetslipResult.Placed -> onPlaced(result.message, result.slipJSON, result.balance)
                }
            }
        },
        update = { view -> adapter.updateProps(view, params) },
        modifier = modifier,
    )
}
