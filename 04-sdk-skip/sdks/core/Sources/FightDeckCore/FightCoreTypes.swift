//
// FightCoreTypes.swift
// FightCore
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

public enum BetMode: String, Codable, Sendable {
    case single
    case accumulator
}

public struct Selection: Codable, Sendable, Hashable, Identifiable {
    public var id: String { "\(boutID)-\(fighterID)" }
    public let boutID: String
    public let fighterID: String
    public let odds: Decimal

    enum CodingKeys: String, CodingKey {
        case boutID = "boutId"
        case fighterID = "fighterId"
        case odds
    }

    public init(boutID: String, fighterID: String, odds: Decimal) {
        self.boutID = boutID
        self.fighterID = fighterID
        self.odds = odds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        boutID = try container.decode(String.self, forKey: .boutID)
        fighterID = try container.decode(String.self, forKey: .fighterID)
        let oddsString = try container.decode(String.self, forKey: .odds)
        odds = Money.parse(oddsString)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(boutID, forKey: .boutID)
        try container.encode(fighterID, forKey: .fighterID)
        try container.encode(Money.format(odds), forKey: .odds)
    }
}

public struct BetSlip: Sendable, Equatable {
    public var mode: BetMode
    public var selections: [Selection]
    public var stake: Decimal

    public init(mode: BetMode, selections: [Selection], stake: Decimal) {
        self.mode = mode
        self.selections = selections
        self.stake = stake
    }
}

public enum ValidationError: String, Codable, Sendable, CaseIterable {
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

    public static let order: [ValidationError] = [
        .emptySlip,
        .stakeBelowMinimum,
        .stakeAboveMaximum,
        .insufficientBalance,
        .tooManySelections,
        .accumulatorNeedsTwoLegs,
        .duplicateBout,
        .unknownBout,
        .fighterNotInBout,
        .payoutExceedsLimit,
    ]
}

public struct SlipState: Sendable {
    public let combinedOddsExact: Decimal?
    public let combinedOddsDisplay: Decimal?
    public let totalStake: Decimal
    public let potentialReturn: Decimal
    public let potentialProfit: Decimal
    public let errors: [ValidationError]

    public init(
        combinedOddsExact: Decimal?,
        combinedOddsDisplay: Decimal?,
        totalStake: Decimal,
        potentialReturn: Decimal,
        potentialProfit: Decimal,
        errors: [ValidationError]
    ) {
        self.combinedOddsExact = combinedOddsExact
        self.combinedOddsDisplay = combinedOddsDisplay
        self.totalStake = totalStake
        self.potentialReturn = potentialReturn
        self.potentialProfit = potentialProfit
        self.errors = errors
    }
}

public enum LegOutcome: String, Codable, Sendable {
    case won
    case lost
    case void
}

public struct LegResult: Sendable {
    public let boutID: String
    public let fighterID: String
    public let outcome: LegOutcome

    public init(boutID: String, fighterID: String, outcome: LegOutcome) {
        self.boutID = boutID
        self.fighterID = fighterID
        self.outcome = outcome
    }
}

public enum SettlementStatus: String, Codable, Sendable {
    case won
    case lost
    case void
    case partiallyWon = "partially_won"
}

public struct Settlement: Sendable {
    public let legs: [LegResult]
    public let returned: Decimal
    public let profit: Decimal
    public let status: SettlementStatus

    public init(legs: [LegResult], returned: Decimal, profit: Decimal, status: SettlementStatus) {
        self.legs = legs
        self.returned = returned
        self.profit = profit
        self.status = status
    }
}

public struct CashOutOffer: Sendable {
    public let available: Bool
    public let amount: Decimal
    public let reason: String?

    public init(available: Bool, amount: Decimal, reason: String?) {
        self.available = available
        self.amount = amount
        self.reason = reason
    }
}

public enum FightCoreError: Error, Sendable {
    case network(retryable: Bool)
    case decoding(field: String)
    case validation(errors: [ValidationError])
}
