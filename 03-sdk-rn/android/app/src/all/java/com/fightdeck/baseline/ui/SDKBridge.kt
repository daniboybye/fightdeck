package com.fightdeck.baseline.ui

import android.app.Application
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import com.fightdeck.baseline.services.DatasetLocator
import com.fightdeck.rn.runtime.FightDeckRNRuntime
import com.fightdeck.rn.runtime.toSnapshot
import com.fightdeck.sdk.betslip.BetslipAdapter
import com.fightdeck.sdk.betslip.BetslipParams
import com.fightdeck.sdk.betslip.BetslipResult
import com.fightdeck.sdk.deposit.DepositAdapter
import com.fightdeck.sdk.deposit.DepositParams
import com.fightdeck.sdk.deposit.DepositResult
import com.fightdeck.sdk.fighter.FighterAdapter
import com.fightdeck.sdk.fighter.FighterParams
import java.math.BigDecimal

@Composable
fun RNDepositScreen(
    balance: BigDecimal,
    onCompleted: (BigDecimal) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val app = context.applicationContext as Application
    val adapter = remember { DepositAdapter() }
    val themeJSON = remember { ThemeLoader.tokensJSON(context) }
    val layoutHandle = rememberRNSurfaceLayout(
        moduleName = "DepositFeature",
        includesTabBarClearance = false,
    )
    var lastPushed by remember { mutableStateOf<RNSurfacePropsFingerprint?>(null) }

    AndroidView(
        modifier = modifier.fillMaxSize(),
        factory = { ctx ->
            adapter.createView(
                ctx,
                app,
                depositParams(
                    balance = balance,
                    themeJSON = themeJSON,
                    layout = layoutHandle.metrics.toSnapshot(),
                ),
            ) { result ->
                if (result is DepositResult.Completed) {
                    onCompleted(result.amount)
                }
            }
        },
        update = { view ->
            layoutHandle.trackHost(view)
            val params = depositParams(
                balance = balance,
                themeJSON = themeJSON,
                layout = layoutHandle.metrics.toSnapshot(),
                textInputActive = layoutHandle.metrics.textInputActive,
            )
            val fingerprint = RNSurfacePropsFingerprint(
                data = listOf(params.currentBalance.toPlainString(), params.themeJSON),
                layout = params.layout,
                textInputActive = params.textInputActive,
            )
            if (fingerprint.data != lastPushed?.data) {
                adapter.updateProps(view, params)
            }
            lastPushed = fingerprint
            view.requestLayout()
        },
        onRelease = { view ->
            FightDeckRNRuntime.stopSurface(view)
        },
    )
}

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
    val context = LocalContext.current
    val app = context.applicationContext as Application
    val adapter = remember { BetslipAdapter() }
    val themeJSON = remember { ThemeLoader.tokensJSON(context) }
    val layoutHandle = rememberRNSurfaceLayout(
        moduleName = "BetslipFeature",
        includesTabBarClearance = true,
    )
    var lastPushed by remember { mutableStateOf<RNSurfacePropsFingerprint?>(null) }

    AndroidView(
        modifier = modifier.fillMaxSize(),
        factory = { ctx ->
            adapter.createView(
                ctx,
                app,
                betslipParams(
                    balance = balance,
                    slipJSON = slipJSON,
                    eventsJSON = eventsJSON,
                    betPlacedMessage = betPlacedMessage,
                    themeJSON = themeJSON,
                    layout = layoutHandle.metrics.toSnapshot(),
                ),
            ) { result ->
                when (result) {
                    is BetslipResult.Updated -> onUpdated(result.slipJSON)
                    BetslipResult.BrowseEvents -> onBrowseEvents()
                    BetslipResult.Deposit -> onDeposit()
                    is BetslipResult.Placed -> onPlaced(result.message, result.slipJSON, result.balance)
                    BetslipResult.Cancelled -> Unit
                }
            }
        },
        update = { view ->
            layoutHandle.trackHost(view)
            val params = betslipParams(
                balance = balance,
                slipJSON = slipJSON,
                eventsJSON = eventsJSON,
                betPlacedMessage = betPlacedMessage,
                themeJSON = themeJSON,
                layout = layoutHandle.metrics.toSnapshot(),
                textInputActive = layoutHandle.metrics.textInputActive,
            )
            val fingerprint = RNSurfacePropsFingerprint(
                data = listOf(
                    params.slipJSON,
                    params.balance.toPlainString(),
                    params.themeJSON,
                    params.eventsJSON,
                    params.betPlacedMessage,
                ),
                layout = params.layout,
                textInputActive = params.textInputActive,
            )
            if (fingerprint.data != lastPushed?.data) {
                adapter.updateProps(view, params)
            }
            lastPushed = fingerprint
            view.requestLayout()
        },
        onRelease = { view ->
            FightDeckRNRuntime.stopSurface(view)
        },
    )
}

@Composable
fun RNFighterProfileScreen(
    fighterJSON: String,
    portraitURL: String,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val app = context.applicationContext as Application
    val adapter = remember { FighterAdapter() }
    val themeJSON = remember { ThemeLoader.tokensJSON(context) }
    val layoutHandle = rememberRNSurfaceLayout(
        moduleName = "FighterFeature",
        includesTabBarClearance = false,
    )
    var lastPushed by remember { mutableStateOf<RNSurfacePropsFingerprint?>(null) }

    AndroidView(
        modifier = modifier.fillMaxSize(),
        factory = { ctx ->
            adapter.createView(
                ctx,
                app,
                fighterParams(
                    fighterJSON = fighterJSON,
                    portraitURL = portraitURL,
                    themeJSON = themeJSON,
                    layout = layoutHandle.metrics.toSnapshot(),
                ),
            )
        },
        update = { view ->
            layoutHandle.trackHost(view)
            val params = fighterParams(
                fighterJSON = fighterJSON,
                portraitURL = portraitURL,
                themeJSON = themeJSON,
                layout = layoutHandle.metrics.toSnapshot(),
            )
            val fingerprint = RNSurfacePropsFingerprint(
                data = listOf(params.fighterJSON, params.portraitURL, params.themeJSON),
                layout = params.layout,
                textInputActive = false,
            )
            if (fingerprint.data != lastPushed?.data) {
                adapter.updateProps(view, params)
            }
            lastPushed = fingerprint
            view.requestLayout()
        },
        onRelease = { view ->
            FightDeckRNRuntime.stopSurface(view)
        },
    )
}

private fun depositParams(
    balance: BigDecimal,
    themeJSON: String,
    layout: com.fightdeck.rn.runtime.RNSurfaceLayoutSnapshot,
    layoutStamp: Double = 1.0,
    textInputActive: Boolean = false,
) = DepositParams(
    themeJSON = themeJSON,
    currentBalance = balance,
    layout = layout,
    textInputActive = textInputActive,
    layoutStamp = layoutStamp,
)

private fun betslipParams(
    balance: BigDecimal,
    slipJSON: String,
    eventsJSON: String,
    betPlacedMessage: String,
    themeJSON: String,
    layout: com.fightdeck.rn.runtime.RNSurfaceLayoutSnapshot,
    layoutStamp: Double = 1.0,
    textInputActive: Boolean = false,
) = BetslipParams(
    themeJSON = themeJSON,
    balance = balance,
    slipJSON = slipJSON,
    eventsJSON = eventsJSON,
    betPlacedMessage = betPlacedMessage,
    layout = layout,
    textInputActive = textInputActive,
    layoutStamp = layoutStamp,
)

private fun fighterParams(
    fighterJSON: String,
    portraitURL: String,
    themeJSON: String,
    layout: com.fightdeck.rn.runtime.RNSurfaceLayoutSnapshot,
    layoutStamp: Double = 1.0,
) = FighterParams(
    themeJSON = themeJSON,
    fighterJSON = fighterJSON,
    portraitURL = portraitURL,
    layout = layout,
    layoutStamp = layoutStamp,
)

private object ThemeLoader {
    fun tokensJSON(context: android.content.Context): String =
        DatasetLocator.tokensJSON(context)
}
