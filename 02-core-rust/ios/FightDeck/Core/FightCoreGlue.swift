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

    /// `amount` is `DepositQuote.amount` from a quote whose `canConfirm` enabled the button,
    /// and FightSlip checks it against the same limits, so a refusal here is a bug to stop on
    /// rather than a deposit to lose without a word.
    func deposit(amount: String) {
        do {
            try store.deposit(amount: amount)
        } catch {
            preconditionFailure("FightSlip refused a confirmed deposit: \(error)")
        }
    }

    func placeBet() {
        store.placeBet()
    }
}

private final class SlipSnapshotListenerBridge: SlipSnapshotListener, @unchecked Sendable {
    var apply: (@MainActor (SlipSnapshot) -> Void)?

    /// Every mutation starts on the main thread, so the snapshot is applied before the call
    /// that caused it returns and the next body pass already sees it. Hopping through a Task
    /// here left the observed state one turn of the run loop behind the store.
    func onSnapshot(snapshot: SlipSnapshot) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { apply?(snapshot) }
        } else {
            Task { @MainActor in apply?(snapshot) }
        }
    }
}
