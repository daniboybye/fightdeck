package com.fightdeck.baseline.core

import java.math.BigDecimal

/**
 * What the host still has to know about a slip. The bet slip screen and every rule behind it
 * live in the SDK's TypeScript core; the host only builds the slip from odds taps on its own
 * event screens, and shows its return in the bar above the tabs — which it has to do before
 * the bet slip surface has ever been mounted, so that one number cannot come from React.
 */
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

/** Two or more legs make an accumulator; the slip never offers a choice. */
const val MIN_ACCA_LEGS = 2

/**
 * A single stakes every leg and rounds each return on its own; an accumulator stakes once on
 * the product of the odds. `contract/fixtures/slip-math.json` pins both.
 */
val BetSlip.potentialReturn: BigDecimal
    get() = when (mode) {
        BetMode.accumulator ->
            Money.money(stake.multiply(selections.fold(BigDecimal.ONE) { acc, sel -> acc.multiply(sel.odds) }))
        BetMode.single ->
            Money.money(selections.fold(BigDecimal.ZERO) { acc, sel -> acc.add(Money.money(stake.multiply(sel.odds))) })
    }
