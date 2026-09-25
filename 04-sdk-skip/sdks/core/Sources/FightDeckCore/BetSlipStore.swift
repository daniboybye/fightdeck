//
// BetSlipStore.swift
// FightDeckCore
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation
import Observation

/// The one place the slip, the balance and the last bet's confirmation live. Both hosts hold a
/// single instance and every surface reads it: the odds buttons on the event screens, the bar
/// above the tabs, the balance toolbar, the deposit sheet and the bet slip SDK.
///
/// In the core rather than in `FightDeckBetslip` because the hosts that link no bet slip — the
/// `runtime` and `deposit` builds — still show odds and a balance. It has no UI of its own.
@Observable
@MainActor
public final class BetSlipStore {
    public private(set) var slip: BetSlip
    public private(set) var balance: Decimal
    public private(set) var betPlacedMessage: String?

    public let fightCore: FightCore

    public init(
        fightCore: FightCore,
        slip: BetSlip = BetSlip(mode: BetMode.single, selections: [], stake: Money.parse("10.00")),
        balance: Decimal = Money.parse("500.00")
    ) {
        self.fightCore = fightCore
        self.slip = slip
        self.balance = balance
    }

    public var slipState: SlipState {
        fightCore.slipState(slip: slip, balance: balance)
    }

    public func isSelected(boutID: String, fighterID: String) -> Bool {
        slip.selections.contains { $0.boutID == boutID && $0.fighterID == fighterID }
    }

    /// One pick per bout: tapping the picked fighter again removes it, tapping the other corner
    /// replaces it.
    public func toggleSelection(boutID: String, fighterID: String, odds: Decimal) {
        if let index = slip.selections.firstIndex(where: { $0.boutID == boutID }) {
            if slip.selections[index].fighterID == fighterID {
                slip.selections.remove(at: index)
            } else {
                slip.selections[index] = Selection(boutID: boutID, fighterID: fighterID, odds: odds)
            }
        } else {
            slip.selections.append(Selection(boutID: boutID, fighterID: fighterID, odds: odds))
        }
        syncMode()
        betPlacedMessage = nil
    }

    public func setStake(_ stake: Decimal) {
        slip.stake = stake
        betPlacedMessage = nil
    }

    public func removeSelection(id: String) {
        slip.selections.removeAll { $0.id == id }
        syncMode()
        betPlacedMessage = nil
    }

    public func placeBet() {
        let state = slipState
        guard state.errors.isEmpty else { return }
        balance -= state.totalStake
        slip.selections.removeAll()
        syncMode()
        betPlacedMessage = "\(Money.formatCurrency(state.potentialReturn)) returns if it lands"
    }

    public func deposit(amount: Decimal) {
        balance += amount
    }

    /// The mode follows the number of legs instead of a picker: one selection is a single, two
    /// or more is an accumulator.
    private func syncMode() {
        slip.mode = slip.selections.count >= FightCore.minAccaLegs ? BetMode.accumulator : BetMode.single
    }
}
