package com.fightdeck.baseline.ui

import android.app.Application
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import com.fightdeck.baseline.services.DatasetLocator
import com.fightdeck.sdk.betslip.BetslipAdapter
import com.fightdeck.sdk.betslip.BetslipParams
import com.fightdeck.sdk.betslip.BetslipResult
import com.fightdeck.sdk.deposit.DepositAdapter
import com.fightdeck.sdk.deposit.DepositParams
import com.fightdeck.sdk.deposit.DepositResult
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
    AndroidView(
        modifier = modifier.fillMaxSize(),
        factory = { ctx ->
            adapter.createView(
                ctx,
                app,
                DepositParams(
                    accessToken = "demo-token",
                    environment = "demo",
                    locale = "en",
                    themeJSON = themeJSON,
                    currentBalance = balance,
                ),
            ) { result ->
                if (result is DepositResult.Completed) {
                    onCompleted(result.amount)
                }
            }
        },
    )
}

@Composable
fun RNBetslipScreen(
    balance: BigDecimal,
    slipJSON: String,
    eventsJSON: String,
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
    AndroidView(
        modifier = modifier.fillMaxSize(),
        factory = { ctx ->
            adapter.createView(
                ctx,
                app,
                BetslipParams(
                    accessToken = "demo-token",
                    environment = "demo",
                    locale = "en",
                    themeJSON = themeJSON,
                    balance = balance,
                    slipJSON = slipJSON,
                    eventsJSON = eventsJSON,
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
    )
}

private object ThemeLoader {
    fun tokensJSON(context: android.content.Context): String =
        DatasetLocator.tokensJSON(context)
}
