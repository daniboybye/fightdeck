//
// FightCoreFixtureTests.swift
// FightDeckTests
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation
import Testing
@testable import FightDeck

@Suite("FightCore fixtures")
struct FightCoreFixtureTests {
    private var core: FightCore { fixtureFightCore() }

    @Test("odds-conversion.json")
    func oddsConversion() throws {
        let data = try FixtureLoader.loadJSON(named: "odds-conversion")
        let root = try JSONDecoder().decode(OddsConversionRoot.self, from: data)
        for testCase in root.cases {
            let decimal = Money.parse(testCase.decimal)
            let fractional = OddsEngine.decimalToFractional(decimal)
            let implied = FightCoreDisplay.formatImpliedProbability(decimal)
            #expect(fractional == testCase.fractional, "Case \(testCase.id): fractional")
            #expect(implied == testCase.impliedProbability, "Case \(testCase.id): implied")
            let roundTrip = OddsEngine.fractionalToDecimal(testCase.fractional)
            #expect(Money.format(roundTrip) == Money.format(decimal), "Case \(testCase.id): round-trip")
        }
    }

    @Test("slip-math.json")
    func slipMath() throws {
        let data = try FixtureLoader.loadJSON(named: "slip-math")
        let root = try JSONDecoder().decode(SlipMathRoot.self, from: data)
        for testCase in root.cases {
            let slip = testCase.slip
            let state = core.slipState(slip: slip, balance: 10_000)
            if let expected = testCase.expect.combinedOddsExact {
                #expect(
                    FightCoreDisplay.formatExactOdds(state.combinedOddsExact ?? 0) == expected,
                    "Case \(testCase.id): combinedOddsExact"
                )
            }
            if let expected = testCase.expect.combinedOddsDisplay {
                #expect(
                    Money.format(state.combinedOddsDisplay ?? 0) == expected,
                    "Case \(testCase.id): combinedOddsDisplay"
                )
            }
            #expect(Money.format(state.totalStake) == testCase.expect.totalStake, "Case \(testCase.id): totalStake")
            #expect(
                Money.format(state.potentialReturn) == testCase.expect.potentialReturn,
                "Case \(testCase.id): potentialReturn"
            )
            #expect(
                Money.format(state.potentialProfit) == testCase.expect.potentialProfit,
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
            let errors = core.validate(slip: slip, balance: Money.parse(testCase.balance))
            let codes = errors.map(\.rawValue)
            #expect(codes == testCase.expect.errors, "Case \(testCase.id)")
        }
    }

    @Test("settlement.json")
    func settlement() throws {
        let data = try FixtureLoader.loadJSON(named: "settlement")
        let root = try JSONDecoder().decode(SettlementRoot.self, from: data)
        for testCase in root.cases {
            let slip = testCase.slip
            let voided = Set(testCase.voidedBouts ?? [])
            let result = core.settle(slip: slip, voidedBouts: voided)
            #expect(Money.format(result.returned) == testCase.expect.returned, "Case \(testCase.id): returned")
            #expect(Money.format(result.profit) == testCase.expect.profit, "Case \(testCase.id): profit")
            #expect(result.status.rawValue == testCase.expect.status, "Case \(testCase.id): status")
            for (leg, expected) in zip(result.legs, testCase.expect.legs) {
                #expect(leg.boutID == expected.boutId)
                #expect(leg.fighterID == expected.fighterId)
                #expect(leg.outcome.rawValue == expected.outcome)
            }
        }
    }

    @Test("cash-out.json")
    func cashOut() throws {
        let data = try FixtureLoader.loadJSON(named: "cash-out")
        let root = try JSONDecoder().decode(CashOutRoot.self, from: data)
        for testCase in root.cases {
            let slip = testCase.slip
            let settled = Set(testCase.settledBouts)
            let offer = core.cashOutOffer(slip: slip, settledBouts: settled)
            #expect(offer.available == testCase.expect.available, "Case \(testCase.id): available")
            #expect(Money.format(offer.amount) == testCase.expect.amount, "Case \(testCase.id): amount")
            #expect(offer.reason == testCase.expect.reason, "Case \(testCase.id): reason")
        }
    }

}

private func fixtureFightCore() -> FightCore {
    let datasetURL = FixtureLoader.fixturesDirectory
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("dataset/events.json")
    let data = try! Data(contentsOf: datasetURL)
    let events = try! JSONDecoder().decode(EventsFile.self, from: data)
    let bouts = events.events.flatMap(\.bouts).map { bout in
        BoutIndex(
            id: bout.id,
            redFighterID: bout.redCorner.fighterId,
            blueFighterID: bout.blueCorner.fighterId,
            winnerID: bout.result.winnerId
        )
    }
    return FightCore(bouts: bouts)
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
    let mode: BetMode
    let stake: String
    let selections: [Selection]
    let expect: SlipMathExpect

    var slip: BetSlip {
        BetSlip(mode: mode, selections: selections, stake: Money.parse(stake))
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
    let mode: BetMode
    let stake: String
    let balance: String
    let selections: [Selection]
    let expect: SlipValidationExpect

    var slip: BetSlip {
        BetSlip(mode: mode, selections: selections, stake: Money.parse(stake))
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
    let mode: BetMode
    let stake: String
    let selections: [Selection]
    let voidedBouts: [String]?
    let expect: SettlementExpect

    var slip: BetSlip {
        BetSlip(mode: mode, selections: selections, stake: Money.parse(stake))
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
    let mode: BetMode
    let stake: String
    let selections: [Selection]
    let settledBouts: [String]
    let expect: CashOutExpect

    var slip: BetSlip {
        BetSlip(mode: mode, selections: selections, stake: Money.parse(stake))
    }
}

private struct CashOutExpect: Decodable {
    let available: Bool
    let amount: String
    let reason: String?
}

private struct EventsFile: Decodable {
    let events: [EventDTO]
}

private struct EventDTO: Decodable {
    let bouts: [BoutDTO]
}

private struct BoutDTO: Decodable {
    let id: String
    let redCorner: CornerDTO
    let blueCorner: CornerDTO
    let result: ResultDTO
}

private struct CornerDTO: Decodable {
    let fighterId: String
}

private struct ResultDTO: Decodable {
    let winnerId: String
}
