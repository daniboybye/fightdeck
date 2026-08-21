//
// BetSlipStore.swift
// FightCore
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import Foundation
import Observation

@Observable
@MainActor
public final class BetSlipStore {
    public var slip: BetSlip
    public var balance: Decimal
    public var settlement: Settlement?

    public let fightCore: FightCore

    public init(
        fightCore: FightCore,
        slip: BetSlip = BetSlip(mode: .accumulator, selections: [], stake: Decimal(string: "10.00")!),
        balance: Decimal = Decimal(string: "500.00")!
    ) {
        self.fightCore = fightCore
        self.slip = slip
        self.balance = balance
    }

    public var slipState: SlipState {
        fightCore.slipState(slip: slip, balance: balance)
    }

    public var cashOutOffer: CashOutOffer {
        fightCore.cashOutOffer(slip: slip, settledBouts: [])
    }

    public func toggleSelection(boutID: String, fighterID: String, odds: Decimal) {
        if let index = slip.selections.firstIndex(where: { $0.boutID == boutID }) {
            let existing = slip.selections[index]
            if existing.fighterID == fighterID {
                slip.selections.remove(at: index)
            } else {
                slip.selections[index] = Selection(boutID: boutID, fighterID: fighterID, odds: odds)
            }
        } else {
            slip.selections.append(Selection(boutID: boutID, fighterID: fighterID, odds: odds))
        }
        settlement = nil
    }

    public func isSelected(boutID: String, fighterID: String) -> Bool {
        slip.selections.contains { $0.boutID == boutID && $0.fighterID == fighterID }
    }

    public func removeSelection(id: String) {
        slip.selections.removeAll { $0.id == id }
        settlement = nil
    }

    public func settleSlip() {
        settlement = fightCore.settle(slip: slip)
    }

    public func deposit(amount: Decimal) {
        balance += amount
    }
}
