//
// BetSlip.swift
// FightDeck
//
// Created by FightDeck on 25.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

// What the host still has to know about a slip. The bet slip screen and every rule behind it
// live in the SDK's TypeScript core; the host only builds the slip from odds taps on its own
// event screens, and shows its return in the accessory above the tabs — which it has to do
// before the bet slip surface has ever been mounted, so that one number cannot come from React.

enum BetMode: String, Codable, Sendable {
    case single
    case accumulator

    /// Two or more legs make an accumulator; the slip never offers a choice.
    static let minAccaLegs = 2
}

struct Selection: Sendable, Hashable {
    let boutID: String
    let fighterID: String
    let odds: Decimal
}

struct BetSlip: Sendable {
    var mode: BetMode
    var selections: [Selection]
    var stake: Decimal

    /// A single stakes every leg and rounds each return on its own; an accumulator stakes once
    /// on the product of the odds. `contract/fixtures/slip-math.json` pins both.
    var potentialReturn: Decimal {
        switch mode {
        case .accumulator:
            Money.money(stake * selections.reduce(Decimal(1)) { $0 * $1.odds })
        case .single:
            Money.money(selections.reduce(Decimal(0)) { $0 + Money.money(stake * $1.odds) })
        }
    }
}
