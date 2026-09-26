package com.fightdeck.swiftcore.core

// An immutable snapshot that Compose can diff, filled from the Swift core after every
// mutation. No rule, rounding, wording or ordering is decided here — see readSnapshot.

/** One leg, as the core captured it. [odds] is already formatted. */
data class SlipLeg(
    val boutId: String,
    val fighterId: String,
    val odds: String,
)

data class SlipSnapshot(
    /** `Single` or `Accumulator`, the label above the legs. */
    val modeTitle: String,
    val legs: List<SlipLeg>,
    /** Two places, no symbol: what the stake field edits. */
    val stake: String,
    /** Two places, no symbol: what the deposit quote is computed against. */
    val balance: String,
    /** `€500.00`, for every toolbar and the slip's balance row. */
    val balanceDisplay: String,
    /** `€361.11`, for the bar that follows the user from tab to tab. */
    val returnDisplay: String,
    /** Label and formatted value, in the order the core lists them. */
    val summaryRows: List<Pair<String, String>>,
    /** One line per validation error, in the contract's order. */
    val errors: List<String>,
    /** Shown where the slip was once a bet is placed; the core clears it. */
    val confirmation: String?,
) {
    fun isSelected(boutId: String, fighterId: String): Boolean =
        legs.any { it.boutId == boutId && it.fighterId == fighterId }
}
