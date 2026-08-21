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
import fight.deck.betslip.binary.BetslipComposeEntry
import fight.deck.betslip.binary.BetslipTheme
import fight.deck.betslip.binary.BetSlipStore
import fight.deck.deposit.binary.DepositComposeEntry
import fight.deck.deposit.binary.DepositParams
import fight.deck.deposit.binary.DepositResult
import java.util.Locale

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
        val stateHolder = rememberSaveableStateHolder()
        stateHolder.SaveableStateProvider(saveKey) {
            val themeJSON = remember { ThemeLoader.tokensJSON(context) }
            val fightCore = remember { SdkFightCoreFactory.build(context) }
            val store = remember(slip, balance) {
                BetSlipStore(
                    fightCore = fightCore,
                    slip = SdkSlipMapper.toSdkSlip(slip),
                    balance = balance,
                )
            }
            val display = remember(viewModel) { HostSlipDisplayContext(viewModel) }
            val theme = remember(themeJSON) { BetslipTheme.parse(themeJSON) }
            BetslipComposeEntry(
                store = store,
                display = display,
                theme = theme,
                onDeposit = onDeposit,
                onBrowseEvents = onBrowseEvents,
                onHostSync = { sdkSlip, sdkBalance, message ->
                    viewModel.applySdkSlip(
                        SdkSlipMapper.toHostSlip(sdkSlip),
                        sdkBalance,
                        message,
                    )
                },
            ).Compose()
            SideEffect { stateHolder.removeState(saveKey) }
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
            SideEffect { stateHolder.removeState(saveKey) }
        }
    }
}
