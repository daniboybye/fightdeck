package com.fightdeck.baseline.ui

import android.app.Application
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import com.fightdeck.baseline.design.Tokens
import com.fightdeck.baseline.services.DatasetLocator
import com.fightdeck.sdk.deposit.DepositAdapter
import com.fightdeck.sdk.deposit.DepositParams
import com.fightdeck.sdk.deposit.DepositResult
import java.math.BigDecimal

/** Deposit-only host — bet slip adapter not linked. */
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
    UnavailableFeature(label = "Bet slip (deposit-only build)", modifier = modifier)
}

@Composable
private fun UnavailableFeature(label: String, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(label, color = Tokens.textSecondary)
    }
}

private object ThemeLoader {
    fun tokensJSON(context: android.content.Context): String =
        DatasetLocator.tokensJSON(context)
}
