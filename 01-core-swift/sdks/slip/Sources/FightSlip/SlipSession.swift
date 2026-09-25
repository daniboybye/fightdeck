//
// SlipSession.swift
// FightSlip
//
// Created by FightDeck on 09.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightCore
#if os(Android)
import FoundationEssentials
#else
import Foundation
#endif

/// Slip state and the mutations over it, with no Observation and no actor isolation.
///
/// `BetSlipStore` adds `@Observable` and `@MainActor` for SwiftUI; the Java bridge wraps
/// the same value for Compose. Everything a bet slip actually does lives here, so both
/// platforms run this code rather than a port of it.
public struct SlipSession: Sendable {
    public var slipEngine: SlipEngine
    public var slip: BetSlip
    public var balance: Decimal

    public init(
        slipEngine: SlipEngine,
        slip: BetSlip = SlipSession.emptySlip,
        balance: Decimal = Decimal(string: "500.00")!
    ) {
        self.slipEngine = slipEngine
        self.slip = slip
        self.balance = balance
    }

    /// No legs and the default stake, in the mode no legs call for. Both hosts start here: iOS
    /// used to override an accumulator default with `.single` and Android took it as it was.
    public static let emptySlip = BetSlip(
        mode: SlipEngine.modeFor(selectionCount: 0),
        selections: [],
        stake: Decimal(string: "10.00")!
    )

    public var slipState: SlipState {
        slipEngine.slipState(slip: slip, balance: balance)
    }

    public mutating func toggleSelection(boutID: String, fighterID: String, odds: Decimal) {
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
        syncMode()
    }

    public func isSelected(boutID: String, fighterID: String) -> Bool {
        slip.selections.contains { $0.boutID == boutID && $0.fighterID == fighterID }
    }

    public mutating func removeSelection(boutID: String, fighterID: String) {
        slip.selections.removeAll { $0.boutID == boutID && $0.fighterID == fighterID }
        syncMode()
    }

    public mutating func removeSelection(id: String) {
        slip.selections.removeAll { $0.id == id }
        syncMode()
    }

    /// Validates, deducts stake, clears selections. Returns the pre-clear slip state when successful.
    public mutating func placeBet() -> SlipState? {
        let state = slipState
        guard state.errors.isEmpty else { return nil }
        balance -= state.totalStake
        slip.selections.removeAll()
        syncMode()
        return state
    }

    public mutating func deposit(amount: Decimal) {
        balance += amount
    }

    private mutating func syncMode() {
        slip.mode = SlipEngine.modeFor(selectionCount: slip.selections.count)
    }
}
