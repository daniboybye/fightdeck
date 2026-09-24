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

enum class ValidationError(val code: String) {
    EMPTY_SLIP("empty_slip"),
    STAKE_BELOW_MINIMUM("stake_below_minimum"),
    STAKE_ABOVE_MAXIMUM("stake_above_maximum"),
    INSUFFICIENT_BALANCE("insufficient_balance"),
    TOO_MANY_SELECTIONS("too_many_selections"),
    ACCUMULATOR_NEEDS_TWO_LEGS("accumulator_needs_two_legs"),
    DUPLICATE_BOUT("duplicate_bout"),
    UNKNOWN_BOUT("unknown_bout"),
    FIGHTER_NOT_IN_BOUT("fighter_not_in_bout"),
    PAYOUT_EXCEEDS_LIMIT("payout_exceeds_limit"),
}

data class SlipState(
    val combinedOddsExact: BigDecimal?,
    val combinedOddsDisplay: BigDecimal?,
    val totalStake: BigDecimal,
    val potentialReturn: BigDecimal,
    val potentialProfit: BigDecimal,
    val errors: List<ValidationError>,
)

data class BoutIndex(
    val id: String,
    val redFighterId: String,
    val blueFighterId: String,
    val winnerId: String,
)
