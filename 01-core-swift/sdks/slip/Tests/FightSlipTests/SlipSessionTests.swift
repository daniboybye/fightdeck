//
// SlipSessionTests.swift
// FightSlipTests
//
// Created by FightDeck on 26.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightCore
import Foundation
import Testing
@testable import FightSlip

@Suite("SlipSession")
struct SlipSessionTests {
    private let bout = BoutIndex(id: "b1", redFighterID: "red", blueFighterID: "blue", winnerID: "red")

    @Test("a new session starts in the mode an empty slip calls for")
    func startingMode() {
        let session = SlipSession(slipEngine: SlipEngine(bouts: [bout]))
        #expect(session.slip.mode == SlipEngine.modeFor(selectionCount: 0))
        #expect(session.slipState.combinedOddsDisplay == nil)
        #expect(session.slipState.totalStake == 0)
        // What the empty slip reports was never the difference: both modes say only this.
        #expect(session.slipState.errors == [.emptySlip])
    }

    @Test("placing a bet leaves a confirmation that only a change to the legs clears")
    func confirmation() {
        var session = SlipSession(slipEngine: SlipEngine(bouts: [bout]))
        session.toggleSelection(boutID: "b1", fighterID: "red", odds: 2)
        #expect(session.placeBet() != nil)
        #expect(session.confirmation == "€20.00 returns if it lands")
        #expect(session.balance == 490)

        session.slip.stake = 5
        session.deposit(amount: 10)
        #expect(session.confirmation != nil)

        session.toggleSelection(boutID: "b1", fighterID: "blue", odds: 2)
        #expect(session.confirmation == nil)
    }
}
