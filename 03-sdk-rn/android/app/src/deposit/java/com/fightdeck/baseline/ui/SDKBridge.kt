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
                DepositParams(
                    themeJSON = themeJSON,
                    currentBalance = balance,
                    layout = layoutHandle.metrics.toSnapshot(),
                    layoutStamp = 1.0,
                ),
            ) { result ->
                if (result is DepositResult.Completed) {
                    onCompleted(result.amount)
                }
            }
        },
        update = { view ->
            layoutHandle.trackHost(view)
            val params = DepositParams(
                themeJSON = themeJSON,
                currentBalance = balance,
                layout = layoutHandle.metrics.toSnapshot(),
                textInputActive = layoutHandle.metrics.textInputActive,
                layoutStamp = 1.0,
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
    UnavailableFeature(label = "Bet slip (deposit-only build)", modifier = modifier)
}

@Composable
private fun UnavailableFeature(label: String, modifier: Modifier = Modifier) {
    androidx.compose.foundation.layout.Box(modifier.fillMaxSize(), contentAlignment = androidx.compose.ui.Alignment.Center) {
        androidx.compose.material3.Text(label, color = androidx.compose.material3.MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

private object ThemeLoader {
    fun tokensJSON(context: android.content.Context): String =
        DatasetLocator.tokensJSON(context)
}
