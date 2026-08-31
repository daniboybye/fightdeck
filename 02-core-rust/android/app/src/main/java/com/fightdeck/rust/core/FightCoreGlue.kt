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
import uniffi.fightcore.validationErrorCode

/**
 * Hand-written glue: UniFFI exposes [BetSlipStore]; Compose needs a [StateFlow].
 */
class StateFlowBetSlipStore(store: BetSlipStore) : AutoCloseable {
    private val store = store
    private val listener = SlipStateListenerBridge()
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    private val _slipState: MutableStateFlow<SlipStateRecord>
    val slipState: StateFlow<SlipStateRecord>

    private val _slip: MutableStateFlow<BetSlipRecord>
    val slip: StateFlow<BetSlipRecord>

    private val _balance: MutableStateFlow<String>
    val balance: StateFlow<String>

    init {
        store.setMode(BetModeRecord.SINGLE)
        _slipState = MutableStateFlow(store.currentState())
        slipState = _slipState.asStateFlow()
        _slip = MutableStateFlow(store.currentSlip())
        slip = _slip.asStateFlow()
        _balance = MutableStateFlow(store.balance())
        balance = _balance.asStateFlow()
        // Last, and deliberately so: adding a listener replays the current state, and the bridge
        // hands that to the main thread. Registering first meant the replay could reach
        // applyListenerUpdate while these flows were still null, killing the app on launch.
        listener.onUpdate = { state -> applyListenerUpdate(state) }
        store.addListener(listener)
    }

    private fun applyListenerUpdate(state: SlipStateRecord) {
        _slipState.value = state
        _slip.value = store.currentSlip()
        _balance.value = store.balance()
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
        // Straight from the store, not the mirror: listener updates arrive on a later main-thread
        // post, so right after a stake edit the published copy is one edit behind.
        val state = store.currentState()
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

    private inner class SlipStateListenerBridge : SlipStateListener {
        var onUpdate: ((SlipStateRecord) -> Unit)? = null

        override fun onSlipStateChanged(state: SlipStateRecord) {
            val callback = onUpdate ?: return
            mainHandler.post { callback(state) }
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
