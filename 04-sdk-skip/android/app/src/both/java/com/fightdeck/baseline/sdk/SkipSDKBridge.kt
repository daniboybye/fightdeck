package com.fightdeck.baseline.sdk

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fightdeck.baseline.ui.MainViewModel
import fight.deck.betslip.BetSlipRootView
import fight.deck.core.ThemeTokens
import fight.deck.deposit.DepositComposeEntry
import fight.deck.deposit.DepositParams
import fight.deck.deposit.DepositResult

object SkipSDKBridge {
    @Composable
    fun BetslipScreen(
        viewModel: MainViewModel,
        saveKey: String,
        onDeposit: () -> Unit,
        onBrowseEvents: () -> Unit,
        modifier: Modifier = Modifier,
    ) {
        val slip by viewModel.slip.collectAsStateWithLifecycle()
        val balance by viewModel.balance.collectAsStateWithLifecycle()
        val betPlacedMessage by viewModel.betPlacedMessage.collectAsStateWithLifecycle()
        // Collected rather than read off the flow inside the display context: a plain `.value`
        // read is not a composition input, so selection rows kept showing fighter ids when the
        // slip opened before the roster finished loading.
        val fighters by viewModel.fighters.collectAsStateWithLifecycle()
        val events by viewModel.events.collectAsStateWithLifecycle()
        val stateHolder = rememberSaveableStateHolder()
        stateHolder.SaveableStateProvider(saveKey) {
            val store = SdkBetSlipStoreRegistry.store(viewModel)
            LaunchedEffect(slip) {
                store.slip = slip
            }
            LaunchedEffect(balance) {
                store.balance = balance
            }
            // The host clears the confirmation when the slip changes from another tab; without
            // pushing that back the SDK keeps showing "bet placed" over an empty slip.
            LaunchedEffect(betPlacedMessage) {
                store.betPlacedMessage = betPlacedMessage
            }
            val display = remember(fighters, events) { HostSlipDisplayContext(fighters, events) }
            val theme = remember { ThemeTokens.defaults }
            // The SDK view composes into whatever box it is given and reads no insets of its
            // own, so the host's top-bar padding has to be a real box around it. Without one the
            // list scrolls under the Bet Slip toolbar.
            Box(modifier) {
                BetSlipRootView(
                    store = store,
                    display = display,
                    theme = theme,
                    onDeposit = onDeposit,
                    onBrowseEvents = onBrowseEvents,
                    onHostSync = { sdkSlip, sdkBalance, message ->
                        viewModel.applySdkSlip(
                            sdkSlip,
                            sdkBalance,
                            message,
                        )
                    },
                ).Compose()
            }
            DisposableEffect(saveKey) {
                onDispose {
                    stateHolder.removeState(saveKey)
                }
            }
        }
    }

    @Composable
    fun FighterScreen(
        fighter: fight.deck.core.Fighter,
        viewModel: MainViewModel,
        saveKey: String,
        modifier: Modifier = Modifier,
    ) {
        UnavailableFeature("Fighter profile (both-only build)", modifier)
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
        Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
