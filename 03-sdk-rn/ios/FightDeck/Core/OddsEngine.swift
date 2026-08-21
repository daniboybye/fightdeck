//
// OddsEngine.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import Foundation

enum OddsEngine {
    static func decimalToFractional(_ decimalOdds: Decimal) -> String {
        let profit = decimalOdds - 1
        let scaled = NSDecimalNumber(decimal: profit * 10_000).intValue
        let divisor = gcd(abs(scaled), 10_000)
        return "\(scaled / divisor)/\(10_000 / divisor)"
    }

    static func fractionalToDecimal(_ fractional: String) -> Decimal {
        let parts = fractional.split(separator: "/")
        guard parts.count == 2,
              let numerator = Int(parts[0]),
              let denominator = Int(parts[1]),
              denominator > 0 else {
            return 0
        }
        let profit = Decimal(numerator) / Decimal(denominator)
        return Money.money(profit + 1)
    }

    static func impliedProbability(_ decimalOdds: Decimal) -> Decimal {
        Money.round(1 / decimalOdds, scale: 4)
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var x = a
        var y = b
        while y != 0 {
            let temp = y
            y = x % y
            x = temp
        }
        return max(x, 1)
    }
}