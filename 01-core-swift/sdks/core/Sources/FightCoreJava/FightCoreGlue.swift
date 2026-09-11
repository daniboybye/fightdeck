//
// FightCoreJava.swift
// FightCoreJava
//
// Created by FightDeck on 09.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightCore
import Foundation

// jextract maps Int, String, Bool, arrays and imported types, but has no mapping for
// Decimal — the type every amount and every odd in FightCore is written in. Money
// therefore crosses as a decimal string in en_US_POSIX form ("361.11"), parsed back with
// Money.parse on this side. Kotlin turns it into BigDecimal, never into Double.

/// Rounds to two places and formats without a currency symbol.
public func formatMoney(_ amount: String) -> String {
    Money.format(Money.parse(amount))
}

/// Rounds to two places and prefixes the euro sign, matching the iOS balance toolbar.
public func formatCurrency(_ amount: String) -> String {
    Money.formatCurrency(Money.parse(amount))
}

public func formatOdds(_ odds: String) -> String {
    FightCoreDisplay.formatOdds(Money.parse(odds))
}

/// Full precision, for the accumulator row where rounding would hide the trap.
public func formatExactOdds(_ odds: String) -> String {
    FightCoreDisplay.formatExactOdds(Money.parse(odds))
}

public func decimalToFractional(_ odds: String) -> String {
    OddsEngine.decimalToFractional(Money.parse(odds))
}

public func fractionalToDecimal(_ fractional: String) -> String {
    Money.format(OddsEngine.fractionalToDecimal(fractional))
}

public func impliedProbability(_ odds: String) -> String {
    FightCoreDisplay.formatImpliedProbability(Money.parse(odds))
}

/// The contract's error codes, as a Java enum rather than loose strings.
public enum SlipValidationError: String {
    case emptySlip = "empty_slip"
    case stakeBelowMinimum = "stake_below_minimum"
    case stakeAboveMaximum = "stake_above_maximum"
    case insufficientBalance = "insufficient_balance"
    case tooManySelections = "too_many_selections"
    case accumulatorNeedsTwoLegs = "accumulator_needs_two_legs"
    case duplicateBout = "duplicate_bout"
    case unknownBout = "unknown_bout"
    case fighterNotInBout = "fighter_not_in_bout"
    case payoutExceedsLimit = "payout_exceeds_limit"
}

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
    private var bouts: [BoutIndex] = []

    public init() {
        session = SlipSession(fightCore: FightCore(bouts: []))
    }

    /// Bouts arrive from the dataset on the Kotlin side, one call per bout, because
    /// handing jextract a `[BoutIndex]` would mean extracting FightCore itself — and its
    /// public API is Decimal from end to end.
    public func registerBout(
        id: String,
        redFighterID: String,
        blueFighterID: String,
        winnerID: String
    ) {
        bouts.append(
            BoutIndex(
                id: id,
                redFighterID: redFighterID,
                blueFighterID: blueFighterID,
                winnerID: winnerID
            )
        )
        session.fightCore = FightCore(bouts: bouts)
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
        session.settlement = nil
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

    public func isSelected(boutID: String, fighterID: String) -> Bool {
        session.isSelected(boutID: boutID, fighterID: fighterID)
    }

    public func updateStake(_ stake: String) {
        session.slip.stake = Money.parse(stake)
    }

    public func deposit(_ amount: String) {
        session.deposit(amount: Money.parse(amount))
    }

    /// Returns false when the slip has validation errors, matching `BetSlipStore.placeBet`
    /// returning nil. The placed slip's figures stay readable through `lastPlaced…`.
    public func placeBet() -> Bool {
        guard let placed = session.placeBet() else { return false }
        lastPlacedReturnText = Money.format(placed.potentialReturn)
        return true
    }

    public private(set) var lastPlacedReturnText: String = ""

    public func settle(voidedBoutIDs: [String]) -> SettlementResult {
        SettlementResult(
            session.fightCore.settle(slip: session.slip, voidedBouts: Set(voidedBoutIDs))
        )
    }

    public func cashOutOffer(settledBoutIDs: [String]) -> CashOutResult {
        CashOutResult(
            session.fightCore.cashOutOffer(slip: session.slip, settledBouts: Set(settledBoutIDs))
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
        return FightCoreDisplay.formatExactOdds(exact)
    }

    public var errors: [SlipValidationError] {
        session.slipState.errors.compactMap { SlipValidationError(rawValue: $0.rawValue) }
    }
}
