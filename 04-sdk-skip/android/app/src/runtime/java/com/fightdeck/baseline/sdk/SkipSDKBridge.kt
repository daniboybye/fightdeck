package com.fightdeck.baseline.sdk

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.fightdeck.baseline.ui.MainViewModel

/** Runtime-only host — Skip core runtime without feature SDK surfaces. */
object SkipSDKBridge {
    @Composable
    fun BetslipScreen(
        viewModel: MainViewModel,
        saveKey: String,
        onDeposit: () -> Unit,
        onBrowseEvents: () -> Unit,
        modifier: Modifier = Modifier,
    ) {
        UnavailableFeature("Bet slip (runtime-only build)", modifier)
    }

    @Composable
    fun DepositScreen(
        viewModel: MainViewModel,
        saveKey: String,
        onDone: () -> Unit,
        modifier: Modifier = Modifier,
    ) {
        UnavailableFeature("Deposit (runtime-only build)", modifier)
    }

    @Composable
    private fun UnavailableFeature(label: String, modifier: Modifier = Modifier) {
        Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
