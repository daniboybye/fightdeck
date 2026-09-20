//
// OddsEngine.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

enum OddsEngine {
    static func impliedProbability(_ decimalOdds: Decimal) -> Decimal {
        Money.round(1 / decimalOdds, scale: 4)
    }
}
