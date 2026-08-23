//
// BetSlipStore.swift
// FightDeckBetslip
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import FightDeckCore
import Foundation
import Observation

@Observable
@MainActor
public final class BetSlipStore {
    public var slip: BetSlip
    public var balance: Decimal
    public var betPlacedMessage: String?

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
        betPlacedMessage = "Bet placed · \(Money.formatCurrency(state.potentialReturn)) to return"
    }

    private func syncMode() {
        slip.mode = slip.selections.count >= FightCore.minAccaLegs ? BetMode.accumulator : BetMode.single
    }
}
