//
// OddsEngine.swift
// FightCore
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

public enum OddsEngine {
    public static func decimalToFractional(_ decimalOdds: Decimal) -> String {
        let profit = decimalOdds - Money.one
        let scale = Money.parse("10000")
        let scaled = decimalScaledInt(profit * scale)
        let divisor = gcd(abs(scaled), 10_000)
        return "\(scaled / divisor)/\(10_000 / divisor)"
    }

    public static func fractionalToDecimal(_ fractional: String) -> Decimal {
        let parts = fractional.split(separator: "/")
        guard parts.count == 2,
              let numerator = Int(parts[0]),
              let denominator = Int(parts[1]),
              denominator > 0 else {
            return Money.zero
        }
        let profit = Money.divide(Money.fromInt(numerator), by: Money.fromInt(denominator))
        return Money.money(profit + Money.one)
    }

    public static func impliedProbability(_ decimalOdds: Decimal) -> Decimal {
        Money.round(Money.divide(Money.one, by: decimalOdds), scale: 4)
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

    private static func decimalScaledInt(_ value: Decimal) -> Int {
        #if SKIP
        return (value as NSNumber).intValue
        #else
        return NSDecimalNumber(decimal: value).intValue
        #endif
    }
}
