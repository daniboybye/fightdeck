package com.fightdeck.rust

import com.fightdeck.rust.core.StateFlowBetSlipStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import uniffi.fightcore.BoutIndex
import uniffi.fightslip.BetSlipStore

class StateFlowBetSlipStoreTest {
    private val store = StateFlowBetSlipStore(
        BetSlipStore(listOf(BoutIndex("b1", "r1", "u1", "r1")), "500.00"),
    )

    /** No looper and no dispatcher: the flow holds the new snapshot when the call returns. */
    @Test
    fun aMutationIsVisibleAsSoonAsItReturns() {
        assertEquals(0, store.snapshot.value.slip.selections.size)

        store.toggleSelection("b1", "r1", "2.50")
        assertEquals(1, store.snapshot.value.slip.selections.size)
        assertEquals("€25.00", store.snapshot.value.state.potentialReturnDisplay)

        store.placeBet()
        assertEquals("€490.00", store.snapshot.value.balanceDisplay)
        assertEquals("€25.00 returns if it lands", store.snapshot.value.confirmation)

        store.toggleSelection("b1", "u1", "1.50")
        assertNull(store.snapshot.value.confirmation)
    }
}
