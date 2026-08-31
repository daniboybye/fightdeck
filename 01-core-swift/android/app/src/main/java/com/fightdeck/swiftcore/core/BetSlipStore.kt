package com.fightdeck.swiftcore.core

import java.math.BigDecimal

/**
 * Mirrors [FightCore.BetSlipStore] until the cross-compiled Swift core is wired on Android.
 */
class BetSlipStore(
    val fightCore: FightCore,
    slip: BetSlip = BetSlip(BetMode.single, emptyList(), BigDecimal("10.00")),
    balance: BigDecimal = BigDecimal("500.00"),
) {
    var slip: BetSlip = slip
        private set
    var balance: BigDecimal = balance
        private set

    val slipState: SlipState
        get() = fightCore.slipState(slip, balance)

    fun toggleSelection(boutId: String, fighterId: String, odds: BigDecimal) {
        val selections = slip.selections.toMutableList()
        val index = selections.indexOfFirst { it.boutId == boutId }
        if (index >= 0) {
            val existing = selections[index]
            if (existing.fighterId == fighterId) {
                selections.removeAt(index)
            } else {
                selections[index] = Selection(boutId, fighterId, odds)
            }
        } else {
            selections += Selection(boutId, fighterId, odds)
        }
        slip = slip.copy(selections = selections)
        syncMode()
    }

    fun isSelected(boutId: String, fighterId: String): Boolean =
        slip.selections.any { it.boutId == boutId && it.fighterId == fighterId }

    fun removeSelection(boutId: String, fighterId: String) {
        slip = slip.copy(
            selections = slip.selections.filterNot {
                it.boutId == boutId && it.fighterId == fighterId
            },
        )
        syncMode()
    }

    fun updateStake(stake: BigDecimal) {
        slip = slip.copy(stake = stake)
    }

    fun placeBet(): SlipState? {
        val state = slipState
        if (state.errors.isNotEmpty()) return null
        balance -= state.totalStake
        slip = slip.copy(selections = emptyList())
        syncMode()
        return state
    }

    fun deposit(amount: BigDecimal) {
        balance += amount
    }

    private fun syncMode() {
        val mode = if (slip.selections.size >= FightCore.MIN_ACCA_LEGS) {
            BetMode.accumulator
        } else {
            BetMode.single
        }
        slip = slip.copy(mode = mode)
    }
}
