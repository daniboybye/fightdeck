package com.fightdeck.rust.core

import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import uniffi.fightcore.BetModeRecord
import uniffi.fightcore.BetSlipRecord
import uniffi.fightcore.BetSlipStore
import uniffi.fightcore.SlipStateListener
import uniffi.fightcore.SlipStateRecord
import uniffi.fightcore.formatCurrency
import uniffi.fightcore.formatMoney
import uniffi.fightcore.impliedProbability

/**
 * Hand-written glue: UniFFI exposes [BetSlipStore]; Compose needs a [StateFlow].
 */
class StateFlowBetSlipStore(store: BetSlipStore) : AutoCloseable {
    private val store = store
    private val listener = SlipStateListenerBridge()
    private val _slipState = MutableStateFlow(store.currentState())
    val slipState: StateFlow<SlipStateRecord> = _slipState.asStateFlow()

    private val _slip = MutableStateFlow(store.currentSlip())
    val slip: StateFlow<BetSlipRecord> = _slip.asStateFlow()

    private val _balance = MutableStateFlow(store.balance())
    val balance: StateFlow<String> = _balance.asStateFlow()

    init {
        store.setMode(BetModeRecord.SINGLE)
        listener.onUpdate = { state ->
            _slipState.value = state
            _slip.value = store.currentSlip()
            _balance.value = store.balance()
        }
        store.addListener(listener)
    }

    fun setStake(stake: String) = store.setStake(stake)
    fun toggleSelection(boutId: String, fighterId: String, odds: String) {
        store.toggleSelection(boutId, fighterId, odds)
        syncMode()
    }

    fun removeSelection(boutId: String, fighterId: String) {
        store.removeSelection(boutId, fighterId)
        syncMode()
    }

    fun isSelected(boutId: String, fighterId: String): Boolean =
        store.isSelected(boutId, fighterId)

    fun deposit(amount: String) = store.deposit(amount)

    fun setBalance(balance: String) = store.setBalance(balance)

    fun placeBet(): SlipStateRecord? {
        val state = _slipState.value
        if (state.errors.isNotEmpty()) return null
        val balance = java.math.BigDecimal(store.balance())
        val stake = java.math.BigDecimal(state.totalStake)
        store.setBalance((balance - stake).toPlainString())
        val selections = store.currentSlip().selections.toList()
        selections.forEach { selection ->
            store.removeSelection(selection.boutId, selection.fighterId)
        }
        syncMode()
        return state
    }

    // The mode follows the number of legs instead of a picker: one selection is a single,
    // two or more is an accumulator. Both modes stay covered by the golden fixtures.
    private fun syncMode() {
        val count = store.currentSlip().selections.size
        val mode = if (count >= FightCoreDisplay.MIN_ACCA_LEGS) {
            BetModeRecord.ACCUMULATOR
        } else {
            BetModeRecord.SINGLE
        }
        store.setMode(mode)
    }

    override fun close() {
        store.close()
    }

    private class SlipStateListenerBridge : SlipStateListener {
        var onUpdate: ((SlipStateRecord) -> Unit)? = null

        override fun onSlipStateChanged(state: SlipStateRecord) {
            onUpdate?.invoke(state)
        }
    }
}

object FightCoreDisplay {
    const val MIN_ACCA_LEGS = 2

    fun formatOdds(odds: String): String = formatMoney(odds)
    fun formatCurrencyAmount(amount: String): String = formatCurrency(amount)
    fun formatImpliedProbability(odds: String): String = impliedProbability(odds)

    fun slipSummary(state: SlipStateRecord): List<Pair<String, String>> = buildList {
        add("Total stake" to formatCurrencyAmount(state.totalStake))
        state.combinedOddsDisplay?.let { add("Combined odds" to formatMoney(it)) }
        add("Potential return" to formatCurrencyAmount(state.potentialReturn))
        add("Potential profit" to formatCurrencyAmount(state.potentialProfit))
    }
}

/** Platform port: [uniffi.fightcore.PreferencesStore] → SharedPreferences. */
class SharedPreferencesStore(
    private val preferences: SharedPreferences,
) : uniffi.fightcore.PreferencesStore {
    override fun read(key: String): String? = preferences.getString(key, null)

    override fun write(key: String, value: String) {
        preferences.edit().putString(key, value).apply()
    }
}

fun validationErrorCode(error: uniffi.fightcore.ValidationErrorRecord): String =
    when (error) {
        uniffi.fightcore.ValidationErrorRecord.EMPTY_SLIP -> "empty_slip"
        uniffi.fightcore.ValidationErrorRecord.STAKE_BELOW_MINIMUM -> "stake_below_minimum"
        uniffi.fightcore.ValidationErrorRecord.STAKE_ABOVE_MAXIMUM -> "stake_above_maximum"
        uniffi.fightcore.ValidationErrorRecord.INSUFFICIENT_BALANCE -> "insufficient_balance"
        uniffi.fightcore.ValidationErrorRecord.TOO_MANY_SELECTIONS -> "too_many_selections"
        uniffi.fightcore.ValidationErrorRecord.ACCUMULATOR_NEEDS_TWO_LEGS -> "accumulator_needs_two_legs"
        uniffi.fightcore.ValidationErrorRecord.DUPLICATE_BOUT -> "duplicate_bout"
        uniffi.fightcore.ValidationErrorRecord.UNKNOWN_BOUT -> "unknown_bout"
        uniffi.fightcore.ValidationErrorRecord.FIGHTER_NOT_IN_BOUT -> "fighter_not_in_bout"
        uniffi.fightcore.ValidationErrorRecord.PAYOUT_EXCEEDS_LIMIT -> "payout_exceeds_limit"
    }
