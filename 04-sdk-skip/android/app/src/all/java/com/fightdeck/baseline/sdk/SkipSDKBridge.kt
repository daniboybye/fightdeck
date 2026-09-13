package com.fightdeck.baseline.sdk

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import fight.deck.core.Fighter
import com.fightdeck.baseline.ui.MainViewModel
import fight.deck.betslip.BetslipComposeEntry
import fight.deck.betslip.BetslipTheme
import fight.deck.deposit.DepositComposeEntry
import fight.deck.deposit.DepositParams
import fight.deck.deposit.DepositResult
import fight.deck.fighter.FighterComposeEntry
import fight.deck.fighter.FighterParams
import fight.deck.fighter.FighterTheme
import java.util.Locale
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

object SkipSDKBridge {
    @Composable
    fun BetslipScreen(
        viewModel: MainViewModel,
        saveKey: String,
        onDeposit: () -> Unit,
        onBrowseEvents: () -> Unit,
        modifier: Modifier = Modifier,
    ) {
        val context = LocalContext.current
        val slip by viewModel.slip.collectAsStateWithLifecycle()
        val balance by viewModel.balance.collectAsStateWithLifecycle()
        val betPlacedMessage by viewModel.betPlacedMessage.collectAsStateWithLifecycle()
        val fighters by viewModel.fighters.collectAsStateWithLifecycle()
        val events by viewModel.events.collectAsStateWithLifecycle()
        val stateHolder = rememberSaveableStateHolder()
        stateHolder.SaveableStateProvider(saveKey) {
            val themeJSON = remember { ThemeLoader.tokensJSON(context) }
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
            val theme = remember(themeJSON) { BetslipTheme.parse(themeJSON) }
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
        val context = LocalContext.current
        val stateHolder = rememberSaveableStateHolder()
        stateHolder.SaveableStateProvider(saveKey) {
            val themeJSON = remember { ThemeLoader.tokensJSON(context) }
            val params = remember(fighter, themeJSON) {
                FighterParams(
                    themeJSON = themeJSON,
                    fighterJSON = fighterJson.encodeToString(fighter),
                    portraitURL = viewModel.imageUrl(fighter.portrait).orEmpty(),
                )
            }
            val theme = remember(themeJSON) { FighterTheme.parse(themeJSON) }
            FighterComposeEntry(
                params = params,
                theme = theme,
            ).Compose()
            DisposableEffect(saveKey) {
                onDispose {
                    stateHolder.removeState(saveKey)
                }
            }
        }
    }

    private val fighterJson = Json { ignoreUnknownKeys = true }
}
