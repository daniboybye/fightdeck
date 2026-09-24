package com.fightdeck.baseline.ui

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.fightdeck.baseline.services.DatasetLocator
import com.fightdeck.rn.runtime.BetslipResult
import com.fightdeck.rn.runtime.DepositResult
import com.fightdeck.sdk.betslip.BetslipAdapter
import com.fightdeck.sdk.betslip.BetslipParams
import com.fightdeck.sdk.deposit.DepositAdapter
import com.fightdeck.sdk.deposit.DepositParams
import java.math.BigDecimal

@Composable
fun RNDepositScreen(
    balance: BigDecimal,
    onCompleted: (BigDecimal) -> Unit,
    onConfirmed: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val adapter = remember { DepositAdapter() }
    val params = DepositParams(themeJSON = rememberThemeJSON(), currentBalance = balance)
    RNSurface(
        includesTabBarClearance = false,
        create = { context ->
            adapter.createView(context, params) { result ->
                when (result) {
                    // The confirmation screen means the money has moved; the host drops its
                    // Close button so the sheet cannot leave without crediting the account.
                    DepositResult.Confirmed -> onConfirmed()
                    is DepositResult.Completed -> onCompleted(result.amount)
                }
            }
        },
        update = { view -> adapter.updateProps(view, params) },
        modifier = modifier,
    )
}

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
        themeJSON = rememberThemeJSON(),
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

@Composable
fun RNFighterProfileScreen(
    fighterJSON: String,
    portraitURL: String,
    modifier: Modifier = Modifier,
) {
    UnavailableFeature(label = "Fighter profile (both-features build)", modifier = modifier)
}

@Composable
private fun rememberThemeJSON(): String {
    val context = LocalContext.current
    return remember { DatasetLocator.tokensJSON(context) }
}

@Composable
private fun UnavailableFeature(label: String, modifier: Modifier = Modifier) {
    androidx.compose.foundation.layout.Box(modifier.fillMaxSize(), contentAlignment = androidx.compose.ui.Alignment.Center) {
        androidx.compose.material3.Text(label, color = androidx.compose.material3.MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
