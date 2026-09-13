package com.fightdeck.swiftcore.core

import com.fightdeck.fightcore.FightCoreJava
import com.fightdeck.fightslip.SlipEngine
import com.fightdeck.fightslip.SlipValidationError
import java.math.BigDecimal

object Money {
    fun money(value: BigDecimal): BigDecimal = BigDecimal(format(value))

    fun parse(string: String): BigDecimal =
        runCatching { BigDecimal(string.trim()) }.getOrDefault(BigDecimal.ZERO)

    fun format(value: BigDecimal): String = FightCoreJava.formatMoney(value.toPlainString())

    fun formatCurrency(value: BigDecimal): String =
        FightCoreJava.formatCurrency(value.toPlainString())
}

object OddsEngine {
    fun decimalToFractional(odds: BigDecimal): String =
        FightCoreJava.decimalToFractional(odds.toPlainString())

    fun fractionalToDecimal(fractional: String): BigDecimal =
        BigDecimal(FightCoreJava.fractionalToDecimal(fractional))

    fun impliedProbability(odds: BigDecimal): String =
        FightCoreJava.impliedProbability(odds.toPlainString())
}

class SwiftSlipStore(boutIDs: List<BoutIndex>) {
    private val engine = SlipEngine.init()

    var slip: BetSlip = BetSlip(BetMode.single, emptyList(), BigDecimal("10.00"))
        private set

    var balance: BigDecimal = BigDecimal("500.00")
        private set

    var slipState: SlipState =
        SlipState(null, null, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, emptyList())
        private set

    init {
        boutIDs.forEach { engine.registerBout(it.id, it.redFighterId, it.blueFighterId, it.winnerId) }
        readBack()
    }

    fun toggleSelection(boutId: String, fighterId: String, odds: BigDecimal) {
        engine.toggleSelection(boutId, fighterId, odds.toPlainString())
        readBack()
    }

    fun removeSelection(boutId: String, fighterId: String) {
        engine.removeSelection(boutId, fighterId)
        readBack()
    }

    fun isSelected(boutId: String, fighterId: String): Boolean = engine.isSelected(boutId, fighterId)

    fun updateStake(stake: BigDecimal) {
        engine.updateStake(stake.toPlainString())
        readBack()
    }

    fun deposit(amount: BigDecimal) {
        engine.deposit(amount.toPlainString())
        readBack()
    }

    fun placeBet(): SlipState? {
        val placed = slipState
        if (!engine.placeBet()) return null
        readBack()
        return placed
    }

    private fun readBack() {
        slip = BetSlip(
            mode = if (engine.isAccumulator()) BetMode.accumulator else BetMode.single,
            selections = engine.selections.map {
                Selection(it.boutID, it.fighterID, BigDecimal(it.oddsText))
            },
            stake = BigDecimal(engine.stakeText),
        )
        balance = BigDecimal(engine.balanceText)
        slipState = SlipState(
            combinedOddsExact = engine.combinedOddsExactText.toBigDecimalOrNull(),
            combinedOddsDisplay = engine.combinedOddsText.toBigDecimalOrNull(),
            totalStake = BigDecimal(engine.totalStakeText),
            potentialReturn = BigDecimal(engine.potentialReturnText),
            potentialProfit = BigDecimal(engine.potentialProfitText),
            errors = engine.errors.map(::toValidationError),
        )
    }

    private fun String.toBigDecimalOrNull(): BigDecimal? = if (isEmpty()) null else BigDecimal(this)

    private fun toValidationError(error: SlipValidationError): ValidationError =
        when (error.discriminator) {
            SlipValidationError.Discriminator.EMPTYSLIP -> ValidationError.EMPTY_SLIP
            SlipValidationError.Discriminator.STAKEBELOWMINIMUM -> ValidationError.STAKE_BELOW_MINIMUM
            SlipValidationError.Discriminator.STAKEABOVEMAXIMUM -> ValidationError.STAKE_ABOVE_MAXIMUM
            SlipValidationError.Discriminator.INSUFFICIENTBALANCE -> ValidationError.INSUFFICIENT_BALANCE
            SlipValidationError.Discriminator.TOOMANYSELECTIONS -> ValidationError.TOO_MANY_SELECTIONS
            SlipValidationError.Discriminator.ACCUMULATORNEEDSTWOLEGS -> ValidationError.ACCUMULATOR_NEEDS_TWO_LEGS
            SlipValidationError.Discriminator.DUPLICATEBOUT -> ValidationError.DUPLICATE_BOUT
            SlipValidationError.Discriminator.UNKNOWNBOUT -> ValidationError.UNKNOWN_BOUT
            SlipValidationError.Discriminator.FIGHTERNOTINBOUT -> ValidationError.FIGHTER_NOT_IN_BOUT
            SlipValidationError.Discriminator.PAYOUTEXCEEDSLIMIT -> ValidationError.PAYOUT_EXCEEDS_LIMIT
        }
}
