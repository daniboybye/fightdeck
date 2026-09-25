package com.fightdeck.rust.core

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import uniffi.fightslip.BetSlipStore
import uniffi.fightslip.SlipSnapshot
import uniffi.fightslip.SlipSnapshotListener

/**
 * The whole hand-written cost of the Rust boundary: UniFFI exposes a listener-based
 * [BetSlipStore], Compose wants a [StateFlow]. Mode selection, validation and the place-bet
 * workflow all stay in FightSlip, so this file has no betting rules left in it.
 */
class StateFlowBetSlipStore(private val store: BetSlipStore) : AutoCloseable {
    // Read once here; the listener only reports changes, it does not replay this.
    private val _snapshot = MutableStateFlow(store.currentSnapshot())

    /** The slip, its derived state and the balance, as FightSlip last reported them. */
    val snapshot: StateFlow<SlipSnapshot> = _snapshot.asStateFlow()

    init {
        store.addListener(
            object : SlipSnapshotListener {
                // Assigned on the calling thread: a StateFlow is safe to set from any thread and
                // Compose collects it on main. Posting to the main looper instead left the
                // observed state one frame behind the store even when the tap was already there.
                override fun onSnapshot(snapshot: SlipSnapshot) {
                    _snapshot.value = snapshot
                }
            },
        )
    }

    fun setStake(stake: String) = store.setStake(stake)

    fun toggleSelection(boutId: String, fighterId: String, odds: String) =
        store.toggleSelection(boutId, fighterId, odds)

    fun removeSelection(boutId: String, fighterId: String) =
        store.removeSelection(boutId, fighterId)

    fun deposit(amount: String) {
        store.deposit(amount)
    }

    fun placeBet() = store.placeBet()

    override fun close() {
        store.close()
    }
}
