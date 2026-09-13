//
// FightCoreFixtureTests.swift
// FightCoreTests
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation
import Testing
@testable import FightCore

@Suite("FightCore fixtures")
struct FightCoreFixtureTests {
    @Test("odds-conversion.json")
    func oddsConversion() throws {
        let data = try FixtureLoader.loadJSON(named: "odds-conversion")
        let root = try JSONDecoder().decode(OddsConversionRoot.self, from: data)
        for testCase in root.cases {
            let decimal = Money.parse(testCase.decimal)
            let fractional = OddsEngine.decimalToFractional(decimal)
            let implied = Money.formatImpliedProbability(decimal)
            #expect(fractional == testCase.fractional, "Case \(testCase.id): fractional")
            #expect(implied == testCase.impliedProbability, "Case \(testCase.id): implied")
            let roundTrip = OddsEngine.fractionalToDecimal(testCase.fractional)
            #expect(Money.format(roundTrip) == Money.format(decimal), "Case \(testCase.id): round-trip")
        }
    }
}

private struct OddsConversionRoot: Decodable {
    let cases: [OddsConversionCase]
}

private struct OddsConversionCase: Decodable {
    let id: String
    let decimal: String
    let fractional: String
    let impliedProbability: String
}
