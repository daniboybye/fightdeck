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

// Results cross as labelled tuples rather than as objects. jextract 0.6.0 turns a returned
// class into a Java wrapper whose every getter is another JNI call, and whose Swift instance
// lives until the garbage collector finds the wrapper. A tuple is filled in the one call that
// returns it and arrives as plain Java values, with nothing on this side left to free. Two
// limits shape the signatures: an array of tuples is skipped without a word, and a tuple
// nested in a tuple generates Swift that does not compile — so lists travel as parallel
// arrays of the same length.

/// The Android-facing shell over `SlipSession`. iOS wraps the same session in
/// `BetSlipStore`, which adds `@Observable`; there is no Observation on ART, so Kotlin reads
/// `snapshot()` after every mutating call instead.
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

    /// A slip with errors is left as it was; `confirmation` in the next snapshot says whether
    /// the bet went through.
    public func placeBet() {
        session.placeBet()
    }

    /// Everything the slip screen shows. Amounts without a symbol are two places, the way
    /// `Money.format` writes them; `…Display` carries the euro.
    public func snapshot() -> (
        modeTitle: String,
        legBoutIDs: [String],
        legFighterIDs: [String],
        legOdds: [String],
        stake: String,
        balance: String,
        balanceDisplay: String,
        returnDisplay: String,
        summaryLabels: [String],
        summaryValues: [String],
        errors: [String],
        confirmation: String?
    ) {
        let slip = session.slip
        let state = session.slipState
        let summary = SlipDisplay.slipSummary(state: state)
        return (
            modeTitle: SlipDisplay.modeTitle(slip.mode),
            legBoutIDs: slip.selections.map(\.boutID),
            legFighterIDs: slip.selections.map(\.fighterID),
            legOdds: slip.selections.map { Money.formatOdds($0.odds) },
            stake: Money.format(slip.stake),
            balance: Money.format(session.balance),
            balanceDisplay: Money.formatCurrency(session.balance),
            returnDisplay: Money.formatCurrency(state.potentialReturn),
            summaryLabels: summary.map(\.label),
            summaryValues: summary.map(\.value),
            errors: state.errors.map(\.message),
            confirmation: session.confirmation
        )
    }

    /// The contract's figures for the same slip, in the fixtures' own format, so the device
    /// tests hold the cross-compiled core to the numbers `swift test` checks. A separate call
    /// because jextract names the Java class after every label in the tuple, and one class
    /// name carrying all eighteen is longer than a file name may be.
    public func contractState() -> (
        oddsExact: String?,
        odds: String?,
        totalStake: String,
        potentialReturn: String,
        potentialProfit: String,
        errorCodes: [String]
    ) {
        let state = session.slipState
        return (
            oddsExact: state.combinedOddsExact.map(Money.formatExactOdds),
            odds: state.combinedOddsDisplay.map(Money.format),
            totalStake: Money.format(state.totalStake),
            potentialReturn: Money.format(state.potentialReturn),
            potentialProfit: Money.format(state.potentialProfit),
            errorCodes: state.errors.map(\.rawValue)
        )
    }

    /// `legOutcomes` is one of "won", "lost", "void" per leg, in slip order.
    public func settle(voidedBoutIDs: [String]) -> (
        status: String,
        returned: String,
        profit: String,
        legOutcomes: [String]
    ) {
        let settlement = session.slipEngine.settle(slip: session.slip, voidedBouts: Set(voidedBoutIDs))
        return (
            status: settlement.status.rawValue,
            returned: Money.format(settlement.returned),
            profit: Money.format(settlement.profit),
            legOutcomes: settlement.legs.map(\.outcome.rawValue)
        )
    }

    /// `reason` is nil while the offer stands, otherwise the contract's refusal code.
    public func cashOutOffer(settledBoutIDs: [String]) -> (available: Bool, amount: String, reason: String?) {
        let offer = session.slipEngine.cashOutOffer(slip: session.slip, settledBouts: Set(settledBoutIDs))
        return (available: offer.available, amount: Money.format(offer.amount), reason: offer.reason)
    }
}
