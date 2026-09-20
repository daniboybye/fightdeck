//
// FightCore.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

struct BoutIndex: Sendable {
    let id: String
    let redFighterID: String
    let blueFighterID: String
}

struct FightCore: Sendable {
    static let minStake = Decimal(string: "1.00")!
    static let maxStake = Decimal(string: "5000.00")!
    static let maxSelections = 12
    static let minAccaLegs = 2
    static let maxPayout = Decimal(string: "100000.00")!

    let bouts: [String: BoutIndex]

    init(bouts: [BoutIndex]) {
        self.bouts = Dictionary(uniqueKeysWithValues: bouts.map { ($0.id, $0) })
    }

    func combinedOddsExact(_ selections: [Selection]) -> Decimal {
        selections.reduce(Decimal(1)) { $0 * $1.odds }
    }

    func slipState(slip: BetSlip, balance: Decimal) -> SlipState {
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

    func validate(slip: BetSlip, balance: Decimal) -> [ValidationError] {
        var found = Set<ValidationError>()

        if slip.selections.isEmpty {
            found.insert(.emptySlip)
        }
        if slip.stake < Self.minStake {
            found.insert(.stakeBelowMinimum)
        }
        if slip.stake > Self.maxStake {
            found.insert(.stakeAboveMaximum)
        }
        if slip.selections.count > Self.maxSelections {
            found.insert(.tooManySelections)
        }
        if slip.mode == .accumulator,
           !slip.selections.isEmpty,
           slip.selections.count < Self.minAccaLegs {
            found.insert(.accumulatorNeedsTwoLegs)
        }

        let boutIDs = slip.selections.map(\.boutID)
        if Set(boutIDs).count != boutIDs.count {
            found.insert(.duplicateBout)
        }

        var hasUnknownBout = false
        for selection in slip.selections {
            guard let bout = bouts[selection.boutID] else {
                found.insert(.unknownBout)
                hasUnknownBout = true
                continue
            }
            let corners = Set([bout.redFighterID, bout.blueFighterID])
            if !corners.contains(selection.fighterID) {
                found.insert(.fighterNotInBout)
            }
        }

        if !slip.selections.isEmpty, !hasUnknownBout {
            let math = computeMath(mode: slip.mode, selections: slip.selections, stake: slip.stake)
            if math.totalStake > balance {
                found.insert(.insufficientBalance)
            }
            if math.potentialReturn > Self.maxPayout {
                found.insert(.payoutExceedsLimit)
            }
        } else if slip.stake > balance {
            found.insert(.insufficientBalance)
        }

        return ValidationError.allCases.filter { found.contains($0) }
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
        case .accumulator:
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

        case .single:
            let totalStake = stake * Decimal(selections.count)
            let potentialReturn = selections.reduce(Decimal(0)) { partial, selection in
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
}
