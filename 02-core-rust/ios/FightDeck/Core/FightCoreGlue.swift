//
// FightCoreGlue.swift
// FightDeck
//
// The whole hand-written cost of the Rust boundary: UniFFI hands back a listener-based
// store, SwiftUI wants @Observable. Everything below the boundary — mode selection, stake
// validation, settlement, the place-bet workflow — stays in FightSlip.
//

import FightSlip
import Foundation
import Observation

@Observable
@MainActor
final class ObservableBetSlipStore {
    /// The slip, its derived state and the balance, as FightSlip last reported them.
    private(set) var snapshot: SlipSnapshot
    private let store: BetSlipStore
    private let listener: SlipSnapshotListenerBridge

    init(store: BetSlipStore) {
        self.store = store
        // Read once here; the listener only reports changes, it does not replay this.
        self.snapshot = store.currentSnapshot()
        let bridge = SlipSnapshotListenerBridge()
        self.listener = bridge
        bridge.apply = { [weak self] snapshot in
            self?.snapshot = snapshot
        }
        store.addListener(listener: bridge)
    }

    func setStake(_ stake: String) {
        store.setStake(stake: stake)
    }

    func toggleSelection(boutId: String, fighterId: String, odds: String) {
        store.toggleSelection(boutId: boutId, fighterId: fighterId, odds: odds)
    }

    func removeSelection(boutId: String, fighterId: String) {
        store.removeSelection(boutId: boutId, fighterId: fighterId)
    }

    func isSelected(boutId: String, fighterId: String) -> Bool {
        store.isSelected(boutId: boutId, fighterId: fighterId)
    }

    func deposit(amount: String) {
        _ = try? store.deposit(amount: amount)
    }

    func placeBet() -> PlaceBetOutcome {
        store.placeBet()
    }
}

private final class SlipSnapshotListenerBridge: SlipSnapshotListener, @unchecked Sendable {
    var apply: (@MainActor (SlipSnapshot) -> Void)?

    func onSnapshot(snapshot: SlipSnapshot) {
        Task { @MainActor in
            apply?(snapshot)
        }
    }
}
