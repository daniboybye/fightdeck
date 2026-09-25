package com.fightdeck.baseline.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import com.fightdeck.rn.runtime.DepositResult
import com.fightdeck.sdk.deposit.DepositAdapter
import com.fightdeck.sdk.deposit.DepositParams
import java.math.BigDecimal

@Composable
fun RNDepositScreen(
    balance: BigDecimal,
    onCompleted: (BigDecimal) -> Unit,
    onConfirmed: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val adapter = remember { DepositAdapter() }
    val params = DepositParams(themeJSON = rememberThemeJSON(), currentBalance = balance)
    RNSurface(
        includesTabBarClearance = false,
        create = { context ->
            adapter.createView(context, params) { result ->
                when (result) {
                    // The confirmation screen means the money has moved; the host drops its
                    // Close button so the sheet cannot leave without crediting the account.
                    DepositResult.Confirmed -> onConfirmed()
                    is DepositResult.Completed -> onCompleted(result.amount)
                }
            }
        },
        update = { view -> adapter.updateProps(view, params) },
        modifier = modifier,
    )
}
