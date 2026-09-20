//
// FightCoreTypes.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

enum BetMode: String, Codable, Sendable {
    case single
    case accumulator
}

struct Selection: Codable, Sendable, Hashable, Identifiable {
    var id: String { "\(boutID)-\(fighterID)" }
    let boutID: String
    let fighterID: String
    let odds: Decimal

    enum CodingKeys: String, CodingKey {
        case boutID = "boutId"
        case fighterID = "fighterId"
        case odds
    }

    init(boutID: String, fighterID: String, odds: Decimal) {
        self.boutID = boutID
        self.fighterID = fighterID
        self.odds = odds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        boutID = try container.decode(String.self, forKey: .boutID)
        fighterID = try container.decode(String.self, forKey: .fighterID)
        let oddsString = try container.decode(String.self, forKey: .odds)
        odds = Money.parse(oddsString)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(boutID, forKey: .boutID)
        try container.encode(fighterID, forKey: .fighterID)
        try container.encode(Money.format(odds), forKey: .odds)
    }
}

struct BetSlip: Sendable {
    var mode: BetMode
    var selections: [Selection]
    var stake: Decimal
}

enum ValidationError: String, Codable, Sendable, CaseIterable {
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

struct SlipState: Sendable {
    let combinedOddsExact: Decimal?
    let combinedOddsDisplay: Decimal?
    let totalStake: Decimal
    let potentialReturn: Decimal
    let potentialProfit: Decimal
    let errors: [ValidationError]
}

enum LegOutcome: String, Codable, Sendable {
    case won
    case lost
    case void
}

struct LegResult: Sendable {
    let boutID: String
    let fighterID: String
    let outcome: LegOutcome
}

enum SettlementStatus: String, Codable, Sendable {
    case won
    case lost
    case void
    case partiallyWon = "partially_won"
}

struct Settlement: Sendable {
    let legs: [LegResult]
    let returned: Decimal
    let profit: Decimal
    let status: SettlementStatus
}

struct CashOutOffer: Sendable {
    let available: Bool
    let amount: Decimal
    let reason: String?
}
