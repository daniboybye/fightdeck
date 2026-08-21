//
// FightCore.swift
// FightCore
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import Foundation

public struct BoutIndex: Sendable {
    public let id: String
    public let redFighterID: String
    public let blueFighterID: String
    public let winnerID: String

    public init(id: String, redFighterID: String, blueFighterID: String, winnerID: String) {
        self.id = id
        self.redFighterID = redFighterID
        self.blueFighterID = blueFighterID
        self.winnerID = winnerID
    }
}

public struct FightCore: Sendable {
    public static let minStake = Decimal(string: "1.00")!
    public static let maxStake = Decimal(string: "5000.00")!
    public static let maxSelections = 12
    public static let minAccaLegs = 2
    public static let maxPayout = Decimal(string: "100000.00")!
    public static let cashOutMargin = Decimal(string: "0.05")!

    public let bouts: [String: BoutIndex]

    public init(bouts: [BoutIndex]) {
        self.bouts = Dictionary(uniqueKeysWithValues: bouts.map { ($0.id, $0) })
    }

    public func combinedOddsExact(_ selections: [Selection]) -> Decimal {
        selections.reduce(Money.one) { $0 * $1.odds }
    }

    public func slipState(slip: BetSlip, balance: Decimal) -> SlipState {
        let errors = validate(slip: slip, balance: balance)
        let math = computeMath(mode: slip.mode, selections: slip.selections, stake: slip.stake)
        return SlipState(
            combinedOddsExact: math.combinedExact,
            combinedOddsDisplay: math.combinedDisplay,
            totalStake: math.totalStake,
            potentialReturn: math.potentialReturn,
            potentialProfit: math.potentialProfit,
            errors: errors
        )
    }

    public func validate(slip: BetSlip, balance: Decimal) -> [ValidationError] {
        var found = Set<ValidationError>()

        if slip.selections.isEmpty {
            found.insert(ValidationError.emptySlip)
        }
        if slip.stake < Self.minStake {
            found.insert(ValidationError.stakeBelowMinimum)
        }
        if slip.stake > Self.maxStake {
            found.insert(ValidationError.stakeAboveMaximum)
        }
        if slip.selections.count > Self.maxSelections {
            found.insert(ValidationError.tooManySelections)
        }
        if slip.mode == BetMode.accumulator,
           !slip.selections.isEmpty,
           slip.selections.count < Self.minAccaLegs {
            found.insert(ValidationError.accumulatorNeedsTwoLegs)
        }

        let boutIDs = slip.selections.map { $0.boutID }
        if Set(boutIDs).count != boutIDs.count {
            found.insert(ValidationError.duplicateBout)
        }

        var hasUnknownBout = false
        for selection in slip.selections {
            guard let bout = bouts[selection.boutID] else {
                found.insert(ValidationError.unknownBout)
                hasUnknownBout = true
                continue
            }
            let corners = Set([bout.redFighterID, bout.blueFighterID])
            if !corners.contains(selection.fighterID) {
                found.insert(ValidationError.fighterNotInBout)
            }
        }

        if !slip.selections.isEmpty, !hasUnknownBout {
            let math = computeMath(mode: slip.mode, selections: slip.selections, stake: slip.stake)
            if math.totalStake > balance {
                found.insert(ValidationError.insufficientBalance)
            }
            if math.potentialReturn > Self.maxPayout {
                found.insert(ValidationError.payoutExceedsLimit)
            }
        } else if slip.stake > balance {
            found.insert(ValidationError.insufficientBalance)
        }

        return ValidationError.order.filter { found.contains($0) }
    }

    public func settle(slip: BetSlip, voidedBouts: Set<String> = []) -> Settlement {
        let outcomes = slip.selections.map { legOutcome(selection: $0, voidedBouts: voidedBouts) }

        switch slip.mode {
        case BetMode.accumulator:
            let totalStake = slip.stake
            if outcomes.contains(where: { $0 == LegOutcome.lost }) {
                return makeSettlement(
                    slip: slip,
                    outcomes: outcomes,
                    returned: Money.zero,
                    totalStake: totalStake,
                    status: SettlementStatus.lost
                )
            }
            let product = zip(slip.selections, outcomes).reduce(Money.one) { partial, pair in
                let (selection, outcome) = pair
                let factor: Decimal = outcome == LegOutcome.void ? Money.one : selection.odds
                return partial * factor
            }
            return makeSettlement(
                slip: slip,
                outcomes: outcomes,
                returned: Money.money(slip.stake * product),
                totalStake: totalStake,
                status: SettlementStatus.won
            )

        case BetMode.single:
            let totalStake = slip.stake * Money.fromInt(slip.selections.count)
            var returned = Money.zero
            for (selection, outcome) in zip(slip.selections, outcomes) {
                switch outcome {
                case LegOutcome.won:
                    returned += Money.money(slip.stake * selection.odds)
                case LegOutcome.void:
                    returned += slip.stake
                case LegOutcome.lost:
                    break
                }
            }
            let wonCount = outcomes.filter { $0 == LegOutcome.won }.count
            let status: SettlementStatus
            if wonCount == outcomes.count {
                status = SettlementStatus.won
            } else if wonCount == 0 {
                status = SettlementStatus.lost
            } else {
                status = SettlementStatus.partiallyWon
            }
            return makeSettlement(
                slip: slip,
                outcomes: outcomes,
                returned: returned,
                totalStake: totalStake,
                status: status
            )
        }
    }

    public func cashOutOffer(slip: BetSlip, settledBouts: Set<String>) -> CashOutOffer {
        guard slip.mode == BetMode.accumulator else {
            return CashOutOffer(available: false, amount: Money.zero, reason: "not_an_accumulator")
        }

        var outcomes: [String: LegOutcome] = [:]
        for selection in slip.selections where settledBouts.contains(selection.boutID) {
            outcomes[selection.boutID] = legOutcome(selection: selection, voidedBouts: [])
        }

        if outcomes.values.contains(where: { $0 == LegOutcome.lost }) {
            return CashOutOffer(available: false, amount: Money.zero, reason: "bet_already_lost")
        }

        let allBoutIDs = Set(slip.selections.map { $0.boutID })
        if settledBouts.intersection(allBoutIDs) == allBoutIDs {
            return CashOutOffer(available: false, amount: Money.zero, reason: "bet_already_settled")
        }

        var fairValue = slip.stake
        for selection in slip.selections {
            if outcomes[selection.boutID] == LegOutcome.won {
                fairValue *= selection.odds
            }
        }

        let amount = Money.money(fairValue * (Money.one - Self.cashOutMargin))
        return CashOutOffer(available: true, amount: amount, reason: nil)
    }

    private struct SlipMath {
        let combinedExact: Decimal?
        let combinedDisplay: Decimal?
        let totalStake: Decimal
        let potentialReturn: Decimal
        let potentialProfit: Decimal
    }

    private func computeMath(mode: BetMode, selections: [Selection], stake: Decimal) -> SlipMath {
        switch mode {
        case BetMode.accumulator:
            let exact = combinedOddsExact(selections)
            let totalStake = stake
            let potentialReturn = Money.money(stake * exact)
            return SlipMath(
                combinedExact: exact,
                combinedDisplay: Money.money(exact),
                totalStake: Money.money(totalStake),
                potentialReturn: potentialReturn,
                potentialProfit: Money.money(potentialReturn - totalStake)
            )

        case BetMode.single:
            let totalStake = stake * Money.fromInt(selections.count)
            let potentialReturn = selections.reduce(Money.zero) { partial, selection in
                partial + Money.money(stake * selection.odds)
            }
            return SlipMath(
                combinedExact: nil,
                combinedDisplay: nil,
                totalStake: Money.money(totalStake),
                potentialReturn: Money.money(potentialReturn),
                potentialProfit: Money.money(potentialReturn - totalStake)
            )
        }
    }

    private func legOutcome(selection: Selection, voidedBouts: Set<String>) -> LegOutcome {
        if voidedBouts.contains(selection.boutID) {
            return LegOutcome.void
        }
        guard let bout = bouts[selection.boutID] else {
            return LegOutcome.lost
        }
        return bout.winnerID == selection.fighterID ? LegOutcome.won : LegOutcome.lost
    }

    private func makeSettlement(
        slip: BetSlip,
        outcomes: [LegOutcome],
        returned: Decimal,
        totalStake: Decimal,
        status: SettlementStatus
    ) -> Settlement {
        let legs = zip(slip.selections, outcomes).map { selection, outcome in
            LegResult(boutID: selection.boutID, fighterID: selection.fighterID, outcome: outcome)
        }
        let roundedReturn = Money.money(returned)
        return Settlement(
            legs: legs,
            returned: roundedReturn,
            profit: Money.money(roundedReturn - totalStake),
            status: status
        )
    }
}
