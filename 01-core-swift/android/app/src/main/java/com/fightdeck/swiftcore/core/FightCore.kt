package com.fightdeck.swiftcore.core

import java.math.BigDecimal
import java.math.RoundingMode

class FightCore(private val bouts: Map<String, BoutIndex>) {
    fun slipState(slip: BetSlip, balance: BigDecimal): SlipState {
        val errors = validate(slip, balance)
        val math = computeMath(slip.mode, slip.selections, slip.stake)
        return SlipState(
            combinedOddsExact = math.combinedExact,
            combinedOddsDisplay = math.combinedDisplay,
            totalStake = math.totalStake,
            potentialReturn = math.potentialReturn,
            potentialProfit = math.potentialProfit,
            errors = errors,
        )
    }

    fun validate(slip: BetSlip, balance: BigDecimal): List<ValidationError> {
        val found = mutableSetOf<ValidationError>()

        if (slip.selections.isEmpty()) found += ValidationError.EMPTY_SLIP
        if (slip.stake < MIN_STAKE) found += ValidationError.STAKE_BELOW_MINIMUM
        if (slip.stake > MAX_STAKE) found += ValidationError.STAKE_ABOVE_MAXIMUM
        if (slip.selections.size > MAX_SELECTIONS) found += ValidationError.TOO_MANY_SELECTIONS
        if (slip.mode == BetMode.accumulator && slip.selections.isNotEmpty() && slip.selections.size < MIN_ACCA_LEGS) {
            found += ValidationError.ACCUMULATOR_NEEDS_TWO_LEGS
        }

        val boutIds = slip.selections.map { it.boutId }
        if (boutIds.size != boutIds.toSet().size) found += ValidationError.DUPLICATE_BOUT

        var hasUnknownBout = false
        for (selection in slip.selections) {
            val bout = bouts[selection.boutId]
            if (bout == null) {
                found += ValidationError.UNKNOWN_BOUT
                hasUnknownBout = true
                continue
            }
            val corners = setOf(bout.redFighterId, bout.blueFighterId)
            if (selection.fighterId !in corners) found += ValidationError.FIGHTER_NOT_IN_BOUT
        }

        if (slip.selections.isNotEmpty() && !hasUnknownBout) {
            val math = computeMath(slip.mode, slip.selections, slip.stake)
            if (math.totalStake > balance) found += ValidationError.INSUFFICIENT_BALANCE
            if (math.potentialReturn > MAX_PAYOUT) found += ValidationError.PAYOUT_EXCEEDS_LIMIT
        } else if (slip.stake > balance) {
            found += ValidationError.INSUFFICIENT_BALANCE
        }

        return ValidationError.order.filter { it in found }
    }

    fun settle(slip: BetSlip, voidedBouts: Set<String> = emptySet()): Settlement {
        val outcomes = slip.selections.map { legOutcome(it, voidedBouts) }

        return when (slip.mode) {
            BetMode.accumulator -> {
                val totalStake = slip.stake
                if (LegOutcome.lost in outcomes) {
                    makeSettlement(slip, outcomes, BigDecimal.ZERO, totalStake, SettlementStatus.lost)
                } else {
                    val product = slip.selections.zip(outcomes).fold(BigDecimal.ONE) { acc, (selection, outcome) ->
                        val factor = if (outcome == LegOutcome.void) BigDecimal.ONE else selection.odds
                        acc.multiply(factor)
                    }
                    makeSettlement(
                        slip,
                        outcomes,
                        Money.money(slip.stake.multiply(product)),
                        totalStake,
                        SettlementStatus.won,
                    )
                }
            }

            BetMode.single -> {
                val totalStake = slip.stake.multiply(BigDecimal(slip.selections.size))
                var returned = BigDecimal.ZERO
                slip.selections.zip(outcomes).forEach { (selection, outcome) ->
                    returned = when (outcome) {
                        LegOutcome.won -> returned.add(Money.money(slip.stake.multiply(selection.odds)))
                        LegOutcome.void -> returned.add(slip.stake)
                        LegOutcome.lost -> returned
                    }
                }
                val wonCount = outcomes.count { it == LegOutcome.won }
                val status = when {
                    wonCount == outcomes.size -> SettlementStatus.won
                    wonCount == 0 -> SettlementStatus.lost
                    else -> SettlementStatus.partially_won
                }
                makeSettlement(slip, outcomes, returned, totalStake, status)
            }
        }
    }

    fun cashOutOffer(slip: BetSlip, settledBouts: Set<String>): CashOutOffer {
        if (slip.mode != BetMode.accumulator) {
            return CashOutOffer(false, BigDecimal.ZERO.setScale(2), "not_an_accumulator")
        }

        val outcomes = slip.selections
            .filter { it.boutId in settledBouts }
            .associate { it.boutId to legOutcome(it, emptySet()) }

        if (LegOutcome.lost in outcomes.values) {
            return CashOutOffer(false, BigDecimal.ZERO.setScale(2), "bet_already_lost")
        }

        val allBoutIds = slip.selections.map { it.boutId }.toSet()
        if (settledBouts.intersect(allBoutIds) == allBoutIds) {
            return CashOutOffer(false, BigDecimal.ZERO.setScale(2), "bet_already_settled")
        }

        var fairValue = slip.stake
        for (selection in slip.selections) {
            if (outcomes[selection.boutId] == LegOutcome.won) {
                fairValue = fairValue.multiply(selection.odds)
            }
        }

        val amount = Money.money(fairValue.multiply(BigDecimal.ONE.subtract(CASH_OUT_MARGIN)))
        return CashOutOffer(true, amount, null)
    }

    private data class SlipMath(
        val combinedExact: BigDecimal?,
        val combinedDisplay: BigDecimal?,
        val totalStake: BigDecimal,
        val potentialReturn: BigDecimal,
        val potentialProfit: BigDecimal,
    )

    private fun computeMath(mode: BetMode, selections: List<Selection>, stake: BigDecimal): SlipMath {
        return when (mode) {
            BetMode.accumulator -> {
                val exact = selections.fold(BigDecimal.ONE) { acc, sel -> acc.multiply(sel.odds) }
                val totalStake = stake
                val potentialReturn = Money.money(stake.multiply(exact))
                SlipMath(
                    combinedExact = exact,
                    combinedDisplay = Money.money(exact),
                    totalStake = Money.money(totalStake),
                    potentialReturn = potentialReturn,
                    potentialProfit = Money.money(potentialReturn.subtract(totalStake)),
                )
            }

            BetMode.single -> {
                val totalStake = stake.multiply(BigDecimal(selections.size))
                val potentialReturn = selections.fold(BigDecimal.ZERO) { acc, sel ->
                    acc.add(Money.money(stake.multiply(sel.odds)))
                }
                SlipMath(
                    combinedExact = null,
                    combinedDisplay = null,
                    totalStake = Money.money(totalStake),
                    potentialReturn = Money.money(potentialReturn),
                    potentialProfit = Money.money(potentialReturn.subtract(totalStake)),
                )
            }
        }
    }

    private fun legOutcome(selection: Selection, voidedBouts: Set<String>): LegOutcome {
        if (selection.boutId in voidedBouts) return LegOutcome.void
        val bout = bouts[selection.boutId] ?: return LegOutcome.lost
        return if (bout.winnerId == selection.fighterId) LegOutcome.won else LegOutcome.lost
    }

    private fun makeSettlement(
        slip: BetSlip,
        outcomes: List<LegOutcome>,
        returned: BigDecimal,
        totalStake: BigDecimal,
        status: SettlementStatus,
    ): Settlement {
        val legs = slip.selections.zip(outcomes).map { (selection, outcome) ->
            LegResult(selection.boutId, selection.fighterId, outcome)
        }
        val roundedReturn = Money.money(returned)
        return Settlement(
            legs = legs,
            returned = roundedReturn,
            profit = Money.money(roundedReturn.subtract(totalStake)),
            status = status,
        )
    }

    companion object {
        val MIN_STAKE: BigDecimal = BigDecimal("1.00")
        val MAX_STAKE: BigDecimal = BigDecimal("5000.00")
        const val MAX_SELECTIONS = 12
        const val MIN_ACCA_LEGS = 2
        val MAX_PAYOUT: BigDecimal = BigDecimal("100000.00")
        val CASH_OUT_MARGIN: BigDecimal = BigDecimal("0.05")

        fun formatExactOdds(value: BigDecimal): String = value.stripTrailingZeros().toPlainString()
    }
}
