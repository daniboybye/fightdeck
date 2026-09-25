//
// FightSlipGlue.swift
// FightSlipJava
//
// Created by FightDeck on 09.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightCore
import FightSlip
#if os(Android)
import FoundationEssentials
#else
import Foundation
#endif

public final class SettlementResult {
    public let status: String
    public let returnedText: String
    public let profitText: String
    /// One of "won", "lost", "void" per leg, in slip order.
    public let legOutcomes: [String]

    init(_ settlement: Settlement) {
        status = settlement.status.rawValue
        returnedText = Money.format(settlement.returned)
        profitText = Money.format(settlement.profit)
        legOutcomes = settlement.legs.map(\.outcome.rawValue)
    }
}

public final class CashOutResult {
    public let available: Bool
    public let amountText: String
    /// Empty when the offer stands; otherwise the contract's refusal code.
    public let reason: String

    init(_ offer: CashOutOffer) {
        available = offer.available
        amountText = Money.format(offer.amount)
        reason = offer.reason ?? ""
    }
}

public final class SlipSelection {
    public let boutID: String
    public let fighterID: String
    public let oddsText: String

    init(_ selection: Selection) {
        boutID = selection.boutID
        fighterID = selection.fighterID
        oddsText = Money.format(selection.odds)
    }
}

/// The Android-facing shell over `SlipSession`. iOS wraps the same session in
/// `BetSlipStore`, which adds `@Observable`; there is no Observation on ART, so Kotlin
/// re-reads the getters after every mutating call instead.
public final class SlipEngine {
    private var session: SlipSession

    /// Takes `EventCatalogBridge.boutIndexJSON` as it is. Handing jextract a `[BoutIndex]`
    /// would mean extracting FightCore itself — and its public API is Decimal from end to end.
    public init(boutIndexJSON: String) {
        let bouts = (try? JSONDecoder().decode([BoutIndex].self, from: Data(boutIndexJSON.utf8))) ?? []
        session = SlipSession(slipEngine: FightSlip.SlipEngine(bouts: bouts))
    }

    /// Replaces the slip wholesale. `toggleSelection` derives the mode from the leg count,
    /// which is what the app wants and what a fixture case, carrying its own mode, does not.
    public func resetSlip(mode: String, stake: String, balance: String) {
        session.slip = BetSlip(
            mode: mode == "accumulator" ? .accumulator : .single,
            selections: [],
            stake: Money.parse(stake)
        )
        session.balance = Money.parse(balance)
    }

    public func addSelection(boutID: String, fighterID: String, odds: String) {
        session.slip.selections.append(
            Selection(boutID: boutID, fighterID: fighterID, odds: Money.parse(odds))
        )
    }

    public func toggleSelection(boutID: String, fighterID: String, odds: String) {
        session.toggleSelection(boutID: boutID, fighterID: fighterID, odds: Money.parse(odds))
    }

    public func removeSelection(boutID: String, fighterID: String) {
        session.removeSelection(boutID: boutID, fighterID: fighterID)
    }

    public func updateStake(_ stake: String) {
        session.slip.stake = Money.parse(stake)
    }

    public func deposit(_ amount: String) {
        session.deposit(amount: Money.parse(amount))
    }

    /// Returns false when the slip has validation errors, matching `BetSlipStore.placeBet`
    /// returning nil.
    public func placeBet() -> Bool {
        session.placeBet() != nil
    }

    public func settle(voidedBoutIDs: [String]) -> SettlementResult {
        SettlementResult(
            session.slipEngine.settle(slip: session.slip, voidedBouts: Set(voidedBoutIDs))
        )
    }

    public func cashOutOffer(settledBoutIDs: [String]) -> CashOutResult {
        CashOutResult(
            session.slipEngine.cashOutOffer(slip: session.slip, settledBouts: Set(settledBoutIDs))
        )
    }

    public var selections: [SlipSelection] {
        session.slip.selections.map(SlipSelection.init)
    }

    public var isAccumulator: Bool {
        session.slip.mode == .accumulator
    }

    public var stakeText: String {
        Money.format(session.slip.stake)
    }

    public var balanceText: String {
        Money.format(session.balance)
    }

    public var totalStakeText: String {
        Money.format(session.slipState.totalStake)
    }

    public var potentialReturnText: String {
        Money.format(session.slipState.potentialReturn)
    }

    public var potentialProfitText: String {
        Money.format(session.slipState.potentialProfit)
    }

    /// Empty for a single-bet slip, where the contract defines no combined odds.
    public var combinedOddsText: String {
        guard let display = session.slipState.combinedOddsDisplay else { return "" }
        return Money.format(display)
    }

    public var combinedOddsExactText: String {
        guard let exact = session.slipState.combinedOddsExact else { return "" }
        return Money.formatExactOdds(exact)
    }

    /// Nil until a bet is placed, and again once the legs change.
    public var confirmation: String? {
        session.confirmation
    }

    /// The contract's codes, in the contract's order.
    public var errorCodes: [String] {
        session.slipState.errors.map(\.rawValue)
    }
}
