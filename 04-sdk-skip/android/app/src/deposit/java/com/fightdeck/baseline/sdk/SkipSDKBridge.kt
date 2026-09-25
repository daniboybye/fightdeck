package com.fightdeck.baseline.sdk

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.ui.Modifier
import com.fightdeck.baseline.ui.MainViewModel
import fight.deck.core.ThemeTokens
import fight.deck.deposit.DepositComposeEntry
import fight.deck.deposit.DepositParams
import fight.deck.deposit.DepositResult

/**
 * Deposit-only host — bet slip SDK not linked.
 *
 * Each SDK screen sits in a `SaveableStateProvider` whose slot is removed when the screen leaves
 * composition. The removal is load-bearing: SkipUI cannot restore its own saved `@FocusState` or
 * `NavigationStack`, so state that survives an activity recreation crashes the screen. See the
 * embedding-seam section of the README.
 */
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
        val balance = viewModel.slipStore.balance
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
                        is DepositResult.CompletedCase -> viewModel.slipStore.deposit(amount = result.amount)
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
