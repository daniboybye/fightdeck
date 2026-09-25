package com.fightdeck.baseline.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import java.math.BigDecimal

/** Stands in for the feature in the measurement flavours that do not link its SDK. */
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
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text("Bet slip is not in this build", color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
