package com.fightdeck.baseline.sdk

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fightdeck.baseline.ui.MainViewModel
import fight.deck.deposit.binary.DepositComposeEntry
import fight.deck.deposit.binary.DepositParams
import fight.deck.deposit.binary.DepositResult
import java.util.Locale

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
    fun DepositScreen(
        viewModel: MainViewModel,
        saveKey: String,
        onDone: () -> Unit,
        modifier: Modifier = Modifier,
    ) {
        val context = LocalContext.current
        val balance by viewModel.balance.collectAsStateWithLifecycle()
        val stateHolder = rememberSaveableStateHolder()
        stateHolder.SaveableStateProvider(saveKey) {
            val themeJSON = remember { ThemeLoader.tokensJSON(context) }
            val params = remember(balance, themeJSON) {
                DepositParams(
                    accessToken = "demo-token",
                    environment = "demo",
                    locale = Locale.getDefault().toLanguageTag(),
                    themeJSON = themeJSON,
                    currentBalance = balance,
                )
            }
            DepositComposeEntry(
                params = params,
                onResult = { result ->
                    when (result) {
                        is DepositResult.CompletedCase -> viewModel.deposit(result.amount)
                        is DepositResult.CancelledCase -> Unit
                        is DepositResult.FailedCase -> Unit
                    }
                    onDone()
                },
            ).Compose()
            SideEffect { stateHolder.removeState(saveKey) }
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
