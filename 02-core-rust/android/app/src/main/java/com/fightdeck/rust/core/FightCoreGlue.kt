package com.fightdeck.rust.core

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import uniffi.fightslip.BetSlipRecord
import uniffi.fightslip.BetSlipStore
import uniffi.fightslip.PlaceBetOutcome
import uniffi.fightslip.SlipStateListener
import uniffi.fightslip.SlipStateRecord

/**
 * The whole hand-written cost of the Rust boundary: UniFFI exposes a listener-based
 * [BetSlipStore], Compose wants a [StateFlow]. Mode selection, validation and the place-bet
 * workflow all stay in FightSlip, so this file has no betting rules left in it.
 */
class StateFlowBetSlipStore(private val store: BetSlipStore) : AutoCloseable {
    private val listener = SlipStateListenerBridge()
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    private val _slipState: MutableStateFlow<SlipStateRecord>
    val slipState: StateFlow<SlipStateRecord>

    private val _slip: MutableStateFlow<BetSlipRecord>
    val slip: StateFlow<BetSlipRecord>

    private val _balance: MutableStateFlow<String>
    val balance: StateFlow<String>

    init {
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

    fun toggleSelection(boutId: String, fighterId: String, odds: String) =
        store.toggleSelection(boutId, fighterId, odds)

    fun removeSelection(boutId: String, fighterId: String) =
        store.removeSelection(boutId, fighterId)

    fun deposit(amount: String) {
        store.deposit(amount)
    }

    fun placeBet(): PlaceBetOutcome = store.placeBet()

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
