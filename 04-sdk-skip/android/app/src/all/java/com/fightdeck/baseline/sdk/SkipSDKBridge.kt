package com.fightdeck.baseline.sdk

import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import fight.deck.core.Fighter
import fight.deck.core.ThemeTokens
import com.fightdeck.baseline.ui.MainViewModel
import fight.deck.betslip.BetslipComposeEntry
import fight.deck.deposit.DepositComposeEntry
import fight.deck.deposit.DepositParams
import fight.deck.deposit.DepositResult
import fight.deck.fighter.FighterComposeEntry
import fight.deck.fighter.FighterParams

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
            LaunchedEffect(betPlacedMessage) {
                store.betPlacedMessage = betPlacedMessage
            }
            val display = remember(fighters, events) { HostSlipDisplayContext(fighters, events) }
            val theme = remember { ThemeTokens.defaults }
            // Same reason as the fighter screen below: the SDK view composes into whatever box
            // it is given and reads no insets of its own, so the host's top-bar padding has to
            // be a real box around it. Without one the list scrolls under the Bet Slip toolbar.
            Box(modifier) {
                BetslipComposeEntry(
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
                        is DepositResult.FailedCase -> Unit
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
    fun FighterScreen(
        fighter: Fighter,
        viewModel: MainViewModel,
        saveKey: String,
        modifier: Modifier = Modifier,
    ) {
        val stateHolder = rememberSaveableStateHolder()
        stateHolder.SaveableStateProvider(saveKey) {
            val theme = remember { ThemeTokens.defaults }
            val params = remember(fighter) {
                FighterParams(
                    fighter = fighter,
                    portraitURL = viewModel.imageUrl(fighter.portrait).orEmpty(),
                )
            }
            // The SDK view composes into whatever box it is given, and it reads no window
            // insets of its own, so the host's top inset has to be a real box around it.
            // Dropping the modifier is what let the hero slide up under the toolbar.
            Box(modifier) {
                FighterComposeEntry(
                    params = params,
                    theme = theme,
                ).Compose()
            }
            DisposableEffect(saveKey) {
                onDispose {
                    stateHolder.removeState(saveKey)
                }
            }
        }
    }
}
