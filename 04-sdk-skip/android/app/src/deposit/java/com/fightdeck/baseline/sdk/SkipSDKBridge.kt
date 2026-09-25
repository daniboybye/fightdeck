package com.fightdeck.baseline.sdk

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fightdeck.baseline.ui.MainViewModel
import fight.deck.core.ThemeTokens
import fight.deck.deposit.DepositComposeEntry
import fight.deck.deposit.DepositParams
import fight.deck.deposit.DepositResult

/** Deposit-only host — bet slip SDK not linked. */
object SkipSDKBridge {
    @Composable
    fun BetslipScreen(
        viewModel: MainViewModel,
        saveKey: String,
        onDeposit: () -> Unit,
        onBrowseEvents: () -> Unit,
        modifier: Modifier = Modifier,
    ) {
        UnavailableFeature("Bet slip (deposit-only build)", modifier)
    }

    @Composable
    fun FighterScreen(
        fighter: fight.deck.core.Fighter,
        viewModel: MainViewModel,
        saveKey: String,
        modifier: Modifier = Modifier,
    ) {
        UnavailableFeature("Fighter profile (deposit-only build)", modifier)
    }

    @Composable
    fun DepositScreen(
        viewModel: MainViewModel,
        saveKey: String,
        onDone: () -> Unit,
        modifier: Modifier = Modifier,
    ) {
        val balance by viewModel.balance.collectAsStateWithLifecycle()
        val stateHolder = rememberSaveableStateHolder()
        stateHolder.SaveableStateProvider(saveKey) {
            val theme = remember { ThemeTokens.defaults }
            val params = remember(balance) {
                DepositParams(currentBalance = balance)
            }
            DepositComposeEntry(
                params = params,
                theme = theme,
                onResult = { result ->
                    when (result) {
                        is DepositResult.CompletedCase -> viewModel.deposit(result.amount)
                        is DepositResult.CancelledCase -> Unit
                    }
                    onDone()
                },
            ).Compose()
            DisposableEffect(saveKey) {
                onDispose {
                    stateHolder.removeState(saveKey)
                }
            }
        }
    }

    @Composable
    private fun UnavailableFeature(label: String, modifier: Modifier = Modifier) {
        androidx.compose.foundation.layout.Box(modifier.fillMaxSize(), contentAlignment = androidx.compose.ui.Alignment.Center) {
            androidx.compose.material3.Text(
                label,
                color = androidx.compose.material3.MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
