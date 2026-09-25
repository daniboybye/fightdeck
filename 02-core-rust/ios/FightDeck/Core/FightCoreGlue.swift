//
// FightCoreGlue.swift
// FightDeck
//
// The whole hand-written cost of the Rust boundary: UniFFI hands back a listener-based
// store, SwiftUI wants @Observable. Everything below the boundary — mode selection, stake
// validation, settlement, the place-bet workflow — stays in FightSlip.
//

import FightCore
import FightSlip
import Foundation
import Observation

@Observable
@MainActor
final class ObservableBetSlipStore {
    private(set) var slipState: SlipStateRecord
    private(set) var slip: BetSlipRecord
    private(set) var balance: String
    private let store: BetSlipStore
    private let listener: SlipStateListenerBridge

    init(store: BetSlipStore) {
        self.store = store
        self.slipState = store.currentState()
        self.slip = store.currentSlip()
        self.balance = store.balance()
        let bridge = SlipStateListenerBridge()
        self.listener = bridge
        bridge.onUpdate = { [weak self] state in
            self?.applyListenerUpdate(state)
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

    private func applyListenerUpdate(_ state: SlipStateRecord) {
        slipState = state
        slip = store.currentSlip()
        balance = store.balance()
    }
}

private final class SlipStateListenerBridge: SlipStateListener, @unchecked Sendable {
    var onUpdate: (@MainActor (SlipStateRecord) -> Void)?

    func onSlipStateChanged(state: SlipStateRecord) {
        Task { @MainActor in
            onUpdate?(state)
        }
    }
}

/// Thin `try?` wrappers over FightCore. The kernel returns an error for unparseable input;
/// a label has nothing useful to do with one, so it shows the raw value instead.
enum FightCoreDisplay {
    static func formatMoneyAmount(_ amount: String) -> String {
        (try? formatMoney(amount: amount)) ?? amount
    }

    static func formatCurrencyAmount(_ amount: String) -> String {
        (try? formatCurrency(amount: amount)) ?? amount
    }
}
