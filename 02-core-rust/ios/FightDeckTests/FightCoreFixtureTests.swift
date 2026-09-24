//
// FightCoreFixtureTests.swift
// FightDeckTests
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightCore
import FightEvents
import FightSlip
import Foundation
import Testing
@testable import FightDeck

@Suite("FightCore fixtures")
struct FightCoreFixtureTests {
    private var core: SlipHandle { fixtureSlipHandle() }

    @Test("odds-conversion.json")
    func oddsConversion() throws {
        let data = try FixtureLoader.loadJSON(named: "odds-conversion")
        let root = try JSONDecoder().decode(OddsConversionRoot.self, from: data)
        for testCase in root.cases {
            let fractional = try decimalToFractional(decimalOdds: testCase.decimal)
            let implied = FightCoreDisplay.formatImpliedProbability(testCase.decimal)
            #expect(fractional == testCase.fractional, "Case \(testCase.id): fractional")
            #expect(implied == testCase.impliedProbability, "Case \(testCase.id): implied")
            let roundTrip = try fractionalToDecimal(fractional: testCase.fractional)
            #expect(try formatMoney(amount: roundTrip) == formatMoney(amount: testCase.decimal), "Case \(testCase.id): round-trip")
        }
    }

    @Test("slip-math.json")
    func slipMath() throws {
        let data = try FixtureLoader.loadJSON(named: "slip-math")
        let root = try JSONDecoder().decode(SlipMathRoot.self, from: data)
        for testCase in root.cases {
            let slip = testCase.slip
            let state = try core.slipState(slip: slip, balance: "10000")
            if let expected = testCase.expect.combinedOddsExact {
                #expect(
                    try formatExactOdds(amount: state.combinedOddsExact ?? "") == expected,
                    "Case \(testCase.id): combinedOddsExact"
                )
            }
            if let expected = testCase.expect.combinedOddsDisplay {
                #expect(
                    try formatMoney(amount: state.combinedOddsDisplay ?? "") == expected,
                    "Case \(testCase.id): combinedOddsDisplay"
                )
            }
            #expect(try formatMoney(amount: state.totalStake) == testCase.expect.totalStake, "Case \(testCase.id): totalStake")
            #expect(
                try formatMoney(amount: state.potentialReturn) == testCase.expect.potentialReturn,
                "Case \(testCase.id): potentialReturn"
            )
            #expect(
                try formatMoney(amount: state.potentialProfit) == testCase.expect.potentialProfit,
                "Case \(testCase.id): potentialProfit"
            )
        }
    }

    @Test("slip-validation.json")
    func slipValidation() throws {
        let data = try FixtureLoader.loadJSON(named: "slip-validation")
        let root = try JSONDecoder().decode(SlipValidationRoot.self, from: data)
        for testCase in root.cases {
            let slip = testCase.slip
            let errors = try core.validate(slip: slip, balance: testCase.balance)
            let codes = errors.map { validationErrorCode(error: $0) }
            #expect(codes == testCase.expect.errors, "Case \(testCase.id)")
        }
    }

    @Test("settlement.json")
    func settlement() throws {
        let data = try FixtureLoader.loadJSON(named: "settlement")
        let root = try JSONDecoder().decode(SettlementRoot.self, from: data)
        for testCase in root.cases {
            let slip = testCase.slip
            let voided = testCase.voidedBouts ?? []
            let result = core.settle(slip: slip, voidedBouts: voided)
            #expect(try formatMoney(amount: result.returned) == testCase.expect.returned, "Case \(testCase.id): returned")
            #expect(try formatMoney(amount: result.profit) == testCase.expect.profit, "Case \(testCase.id): profit")
            #expect(settlementStatusCode(result.status) == testCase.expect.status, "Case \(testCase.id): status")
            for (leg, expected) in zip(result.legs, testCase.expect.legs) {
                #expect(leg.boutId == expected.boutId)
                #expect(leg.fighterId == expected.fighterId)
                #expect(legOutcomeCode(leg.outcome) == expected.outcome)
            }
        }
    }

    @Test("cash-out.json")
    func cashOut() throws {
        let data = try FixtureLoader.loadJSON(named: "cash-out")
        let root = try JSONDecoder().decode(CashOutRoot.self, from: data)
        for testCase in root.cases {
            let slip = testCase.slip
            let settled = testCase.settledBouts
            let offer = core.cashOutOffer(slip: slip, settledBouts: settled)
            #expect(offer.available == testCase.expect.available, "Case \(testCase.id): available")
            #expect(try formatMoney(amount: offer.amount) == testCase.expect.amount, "Case \(testCase.id): amount")
            #expect(offer.reason == testCase.expect.reason, "Case \(testCase.id): reason")
        }
    }
}

/// FightEvents parses the dataset and FightSlip validates against it: the fixtures only pass
/// when both SDKs agree on the same bout index.
private func fixtureSlipHandle() -> SlipHandle {
    let datasetRoot = FixtureLoader.fixturesDirectory
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("dataset")
    let catalog = try! EventCatalog.load(datasetRoot: datasetRoot.path)
    return SlipHandle(bouts: catalog.boutIndex().map {
        BoutIndexRecord(
            id: $0.id,
            redFighterId: $0.redFighterId,
            blueFighterId: $0.blueFighterId,
            winnerId: $0.winnerId
        )
    })
}

private func settlementStatusCode(_ status: SettlementStatusRecord) -> String {
    switch status {
    case .won: "won"
    case .lost: "lost"
    case .void: "void"
    case .partiallyWon: "partially_won"
    }
}

private func legOutcomeCode(_ outcome: LegOutcomeRecord) -> String {
    switch outcome {
    case .won: "won"
    case .lost: "lost"
    case .void: "void"
    }
}

// MARK: - Fixture models

private struct OddsConversionRoot: Decodable {
    let cases: [OddsConversionCase]
}

private struct OddsConversionCase: Decodable {
    let id: String
    let decimal: String
    let fractional: String
    let impliedProbability: String
}

private struct SlipMathRoot: Decodable {
    let cases: [SlipMathCase]
}

private struct SlipMathCase: Decodable {
    let id: String
    let mode: String
    let stake: String
    let selections: [SelectionFixture]
    let expect: SlipMathExpect

    var slip: BetSlipRecord {
        BetSlipRecord(mode: betMode(mode), selections: selections.map(\.record), stake: stake)
    }
}

private struct SlipMathExpect: Decodable {
    let combinedOddsExact: String?
    let combinedOddsDisplay: String?
    let totalStake: String
    let potentialReturn: String
    let potentialProfit: String
}

private struct SlipValidationRoot: Decodable {
    let cases: [SlipValidationCase]
}

private struct SlipValidationCase: Decodable {
    let id: String
    let mode: String
    let stake: String
    let balance: String
    let selections: [SelectionFixture]
    let expect: SlipValidationExpect

    var slip: BetSlipRecord {
        BetSlipRecord(mode: betMode(mode), selections: selections.map(\.record), stake: stake)
    }
}

private struct SlipValidationExpect: Decodable {
    let errors: [String]
}

private struct SettlementRoot: Decodable {
    let cases: [SettlementCase]
}

private struct SettlementCase: Decodable {
    let id: String
    let mode: String
    let stake: String
    let selections: [SelectionFixture]
    let voidedBouts: [String]?
    let expect: SettlementExpect

    var slip: BetSlipRecord {
        BetSlipRecord(mode: betMode(mode), selections: selections.map(\.record), stake: stake)
    }
}

private struct SettlementExpect: Decodable {
    let legs: [SettlementLegExpect]
    let returned: String
    let profit: String
    let status: String
}

private struct SettlementLegExpect: Decodable {
    let boutId: String
    let fighterId: String
    let outcome: String
}

private struct CashOutRoot: Decodable {
    let cases: [CashOutCase]
}

private struct CashOutCase: Decodable {
    let id: String
    let mode: String
    let stake: String
    let selections: [SelectionFixture]
    let settledBouts: [String]
    let expect: CashOutExpect

    var slip: BetSlipRecord {
        BetSlipRecord(mode: betMode(mode), selections: selections.map(\.record), stake: stake)
    }
}

private struct CashOutExpect: Decodable {
    let available: Bool
    let amount: String
    let reason: String?
}

private struct SelectionFixture: Decodable {
    let boutId: String
    let fighterId: String
    let odds: String

    var record: SelectionRecord {
        SelectionRecord(boutId: boutId, fighterId: fighterId, odds: odds)
    }
}

private func betMode(_ raw: String) -> BetModeRecord {
    switch raw {
    case "single": .single
    case "accumulator": .accumulator
    default: fatalError("unknown bet mode: \(raw)")
    }
}
