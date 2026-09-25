package com.fightdeck.baseline.sdk

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.ui.Modifier
import com.fightdeck.baseline.ui.MainViewModel
import fight.deck.core.ThemeTokens
import fight.deck.deposit.DepositComposeEntry
import fight.deck.deposit.DepositParams
import fight.deck.deposit.DepositResult

/**
 * Compiled into every flavour that links the deposit SDK (`deposit`, `both` and `all`). The
 * provider and its removal are there for the reason given in `BetslipSdkBridge.kt`.
 */
@Composable
fun DepositSdkScreen(
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
