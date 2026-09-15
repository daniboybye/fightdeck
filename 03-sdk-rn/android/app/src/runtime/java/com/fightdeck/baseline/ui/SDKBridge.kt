package com.fightdeck.baseline.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import java.math.BigDecimal

/** Runtime-only host — no feature SDK adapters linked. */
@Composable
fun RNDepositScreen(
    balance: BigDecimal,
    onCompleted: (BigDecimal) -> Unit,
    onConfirmed: () -> Unit,
    modifier: Modifier = Modifier,
) {
    UnavailableFeature(label = "Deposit (runtime-only build)", modifier = modifier)
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
    UnavailableFeature(label = "Bet slip (runtime-only build)", modifier = modifier)
}

@Composable
fun RNFighterProfileScreen(
    fighterJSON: String,
    portraitURL: String,
    modifier: Modifier = Modifier,
) {
    UnavailableFeature(label = "Fighter profile (runtime-only build)", modifier = modifier)
}

@Composable
private fun UnavailableFeature(label: String, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
