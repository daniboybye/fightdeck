package com.fightdeck.swiftcore.core

import com.fightdeck.fightcore.FightCoreJava
import com.fightdeck.fightslip.SlipEngine
import java.math.BigDecimal

object Money {
    fun parse(string: String): BigDecimal =
        runCatching { BigDecimal(string.trim()) }.getOrDefault(BigDecimal.ZERO)

    fun format(value: BigDecimal): String = FightCoreJava.formatMoney(value.toPlainString())

    fun formatCurrency(value: BigDecimal): String =
        FightCoreJava.formatCurrency(value.toPlainString())
}

/** [boutIndexJSON] is `EventCatalogBridge.boutIndexJSON`, handed over untouched. */
class SwiftSlipStore(boutIndexJSON: String) {
    private val engine = SlipEngine.init(boutIndexJSON)

    var slip: BetSlip = BetSlip(BetMode.single, emptyList(), BigDecimal("10.00"))
        private set

    var balance: BigDecimal = BigDecimal("500.00")
        private set

    var slipState: SlipState =
        SlipState(null, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, emptyList(), emptyList())
        private set

    /** Set by the core when a bet is placed and cleared when the legs change. */
    var confirmation: String? = null
        private set

    init {
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

    fun updateStake(stake: BigDecimal) {
        engine.updateStake(stake.toPlainString())
        readBack()
    }

    fun deposit(amount: BigDecimal) {
        engine.deposit(amount.toPlainString())
        readBack()
    }

    fun placeBet() {
        if (engine.placeBet()) readBack()
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
            combinedOddsDisplay = engine.combinedOddsText.toBigDecimalOrNull(),
            totalStake = BigDecimal(engine.totalStakeText),
            potentialReturn = BigDecimal(engine.potentialReturnText),
            potentialProfit = BigDecimal(engine.potentialProfitText),
            errors = engine.errorCodes.toList(),
            summaryRows = engine.summaryLabels.zip(engine.summaryValues),
        )
        confirmation = engine.confirmation.orElse(null)
    }

    private fun String.toBigDecimalOrNull(): BigDecimal? = if (isEmpty()) null else BigDecimal(this)
}
