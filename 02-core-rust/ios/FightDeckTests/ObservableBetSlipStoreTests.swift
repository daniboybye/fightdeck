//
// ObservableBetSlipStoreTests.swift
// FightDeckTests
//

import FightSlip
import Testing
@testable import FightDeck

@Suite("ObservableBetSlipStore")
@MainActor
struct ObservableBetSlipStoreTests {
    private func makeStore() throws -> ObservableBetSlipStore {
        let handle = SlipHandle(bouts: [
            BoutIndexRecord(id: "b1", redFighterId: "r1", blueFighterId: "u1", winnerId: "r1"),
        ])
        return ObservableBetSlipStore(store: try BetSlipStore(handle: handle, balance: "500.00"))
    }

    /// The observed snapshot must already reflect a mutation when the call returns, with no
    /// run-loop turn in between: a view reading it straight after a tap sees the new slip.
    @Test func mutationsOnMainApplyBeforeTheCallReturns() throws {
        let store = try makeStore()
        #expect(store.snapshot.slip.selections.isEmpty)

        store.toggleSelection(boutId: "b1", fighterId: "r1", odds: "2.50")
        #expect(store.snapshot.slip.selections.count == 1)
        #expect(store.snapshot.state.potentialReturnDisplay == "€25.00")

        store.placeBet()
        #expect(store.snapshot.slip.selections.isEmpty)
        #expect(store.snapshot.balanceDisplay == "€490.00")
        #expect(store.snapshot.confirmation == "€25.00 returns if it lands")
    }
}
