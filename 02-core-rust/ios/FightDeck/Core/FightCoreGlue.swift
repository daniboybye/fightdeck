//
// FightCoreGlue.swift
// FightDeck
//
// Hand-written glue: UniFFI exposes BetSlipStore; SwiftUI needs @Observable.
//

import Foundation
import Observation

@Observable
@MainActor
final class ObservableBetSlipStore {
    private(set) var slipState: SlipStateRecord
    private let store: BetSlipStore
    private let listener: SlipStateListenerBridge

    init(store: BetSlipStore) {
        self.store = store
        store.setMode(mode: .single)
        self.slipState = store.currentState()
        let bridge = SlipStateListenerBridge()
        self.listener = bridge
        bridge.onUpdate = { [weak self] state in
            self?.slipState = state
        }
        store.addListener(listener: bridge)
    }

    var slip: BetSlipRecord { store.currentSlip() }
    var balance: String { store.balance() }

    func setStake(_ stake: String) { store.setStake(stake: stake) }
    func toggleSelection(boutId: String, fighterId: String, odds: String) {
        store.toggleSelection(boutId: boutId, fighterId: fighterId, odds: odds)
        syncMode()
    }
    func removeSelection(boutId: String, fighterId: String) {
        store.removeSelection(boutId: boutId, fighterId: fighterId)
        syncMode()
    }
    func isSelected(boutId: String, fighterId: String) -> Bool {
        store.isSelected(boutId: boutId, fighterId: fighterId)
    }
    func deposit(amount: String) { store.deposit(amount: amount) }
    func setBalance(_ balance: String) { store.setBalance(balance: balance) }

    /// Deducts stake, clears selections. Returns the pre-clear slip state when successful.
    func placeBet() -> SlipStateRecord? {
        let state = slipState
        guard state.errors.isEmpty else { return nil }
        let balance = Decimal(string: store.balance()) ?? 0
        let stake = Decimal(string: state.totalStake) ?? 0
        let newBalance = balance - stake
        store.setBalance(balance: formatMoney(amount: NSDecimalNumber(decimal: newBalance).stringValue))
        let selections = Array(store.currentSlip().selections)
        for selection in selections {
            store.removeSelection(boutId: selection.boutId, fighterId: selection.fighterId)
        }
        syncMode()
        return state
    }

    /// The mode follows the number of legs instead of a picker: one selection is a single,
    /// two or more is an accumulator. Both modes stay covered by the golden fixtures.
    private func syncMode() {
        let mode: BetModeRecord = slip.selections.count >= FightCoreDisplay.minAccaLegs
            ? .accumulator
            : .single
        store.setMode(mode: mode)
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

enum FightCoreDisplay {
    static let minAccaLegs = 2

    static func formatOdds(_ odds: String) -> String { formatMoney(amount: odds) }
    static func formatCurrencyAmount(_ amount: String) -> String { formatCurrency(amount: amount) }
    static func formatImpliedProbability(_ odds: String) -> String { impliedProbability(decimalOdds: odds) }

    static func slipSummary(state: SlipStateRecord) -> [(label: String, value: String)] {
        var rows: [(String, String)] = [
            ("Total stake", formatCurrencyAmount(state.totalStake)),
        ]
        if let combined = state.combinedOddsDisplay {
            rows.append(("Combined odds", formatMoney(amount: combined)))
        }
        rows.append(("Potential return", formatCurrencyAmount(state.potentialReturn)))
        rows.append(("Potential profit", formatCurrencyAmount(state.potentialProfit)))
        return rows
    }
}

/// Platform port: PreferencesStore → UserDefaults (Rust defines the hole; Swift fills it).
final class UserDefaultsPreferencesStore: PreferencesStore, @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func read(key: String) -> String? {
        defaults.string(forKey: key)
    }

    func write(key: String, value: String) {
        defaults.set(value, forKey: key)
    }
}
