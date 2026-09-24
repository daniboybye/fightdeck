package com.fightdeck.rn.runtime

import java.math.BigDecimal

/** What each feature surface reports back — one case per method in the codegen spec. */
sealed class DepositResult {
    data object Confirmed : DepositResult()
    data class Completed(val amount: BigDecimal) : DepositResult()
}

sealed class BetslipResult {
    data class Updated(val slipJSON: String) : BetslipResult()
    data object BrowseEvents : BetslipResult()
    data object Deposit : BetslipResult()
    data class Placed(val message: String, val slipJSON: String, val balance: String) : BetslipResult()
}
