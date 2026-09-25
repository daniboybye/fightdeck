//
// BetSlipStore.swift
// FightSlip
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightCore
#if os(Android)
import FoundationEssentials
#else
import Foundation
#endif
import Observation

/// SwiftUI's view of a `SlipSession`. The mutations live in the session; this type adds
/// only observation and main-actor isolation, neither of which crosses to Android.
@Observable
@MainActor
public final class BetSlipStore {
    private var session: SlipSession

    public var slip: BetSlip {
        get { session.slip }
        set { session.slip = newValue }
    }

    public var balance: Decimal { session.balance }

    public var confirmation: String? { session.confirmation }

    public init(
        slipEngine: SlipEngine,
        slip: BetSlip = SlipSession.emptySlip,
        balance: Decimal = Decimal(string: "500.00")!
    ) {
        session = SlipSession(slipEngine: slipEngine, slip: slip, balance: balance)
    }

    public var slipState: SlipState { session.slipState }

    public func toggleSelection(boutID: String, fighterID: String, odds: Decimal) {
        session.toggleSelection(boutID: boutID, fighterID: fighterID, odds: odds)
    }

    public func isSelected(boutID: String, fighterID: String) -> Bool {
        session.isSelected(boutID: boutID, fighterID: fighterID)
    }

    public func removeSelection(id: String) {
        session.removeSelection(id: id)
    }

    /// Validates, deducts stake, clears selections. Returns the pre-clear slip state when successful.
    @discardableResult
    public func placeBet() -> SlipState? {
        session.placeBet()
    }

    public func deposit(amount: Decimal) {
        session.deposit(amount: amount)
    }
}
