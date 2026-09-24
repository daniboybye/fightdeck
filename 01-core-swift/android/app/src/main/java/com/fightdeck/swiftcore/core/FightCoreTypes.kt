package com.fightdeck.swiftcore.core

import java.math.BigDecimal

// Immutable snapshots that Compose can diff, filled from the Swift core after every
// mutation. No rule, rounding or ordering is decided here — see SwiftSlipStore.

enum class BetMode {
    single,
    accumulator,
}

data class Selection(
    val boutId: String,
    val fighterId: String,
    val odds: BigDecimal,
)

data class BetSlip(
    val mode: BetMode,
    val selections: List<Selection>,
    val stake: BigDecimal,
)

data class SlipState(
    val combinedOddsExact: BigDecimal?,
    val combinedOddsDisplay: BigDecimal?,
    val totalStake: BigDecimal,
    val potentialReturn: BigDecimal,
    val potentialProfit: BigDecimal,
    /** The contract's error codes, in the contract's order. */
    val errors: List<String>,
)
