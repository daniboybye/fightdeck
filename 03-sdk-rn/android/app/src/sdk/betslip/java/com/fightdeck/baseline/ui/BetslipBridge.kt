package com.fightdeck.baseline.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import com.fightdeck.baseline.core.BetSlip
import com.fightdeck.baseline.core.Selection
import com.fightdeck.baseline.data.EventItem
import com.fightdeck.rn.runtime.BetslipResult
import com.fightdeck.sdk.betslip.BetslipAdapter
import com.fightdeck.sdk.betslip.BetslipParams
import com.fightdeck.sdk.betslip.BetslipSelection
import java.math.BigDecimal

@Composable
fun RNBetslipScreen(
    balance: BigDecimal,
    slip: BetSlip,
    events: List<EventItem>,
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
        stake = slip.stake,
        selections = slip.selections.mapNotNull { it.leg(events) },
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

/** Names each pick from the catalogue the host already has in memory. */
private fun Selection.leg(events: List<EventItem>): BetslipSelection? {
    for (event in events) {
        val bout = event.bouts.firstOrNull { it.id == boutId } ?: continue
        val picked = if (bout.redCorner.fighterId == fighterId) bout.redCorner else bout.blueCorner
        val opponent = if (picked === bout.redCorner) bout.blueCorner else bout.redCorner
        return BetslipSelection(
            boutId = bout.id,
            fighterId = fighterId,
            opponentId = opponent.fighterId,
            odds = odds,
            fighterName = picked.name,
            opponentName = opponent.name,
            eventName = event.name,
        )
    }
    return null
}
