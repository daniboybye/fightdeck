//
// Money.swift
// FightCore
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

public enum Money {
    public static let zero = Decimal(string: "0")!
    public static let one = Decimal(string: "1")!

    public static func round(_ value: Decimal, scale: Int = 2) -> Decimal {
        #if SKIP
        return value.setScale(Int32(scale), java.math.RoundingMode.HALF_UP)
        #else
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, scale, .plain)
        return result
        #endif
    }

    /// Kotlin's `/` on BigDecimal keeps the dividend's scale, so `Money.one / 1.20` is 1 on
    /// Android and 0.8333… on Apple platforms. Shared code has to name the precision it wants
    /// or the two builds of this file disagree about money.
    public static func divide(_ dividend: Decimal, by divisor: Decimal, scale: Int = 10) -> Decimal {
        #if SKIP
        return dividend.divide(divisor, Int32(scale), java.math.RoundingMode.HALF_UP)
        #else
        return round(dividend / divisor, scale: scale)
        #endif
    }

    public static func money(_ value: Decimal) -> Decimal {
        round(value, scale: 2)
    }

    public static func parse(_ string: String) -> Decimal {
        parseOrNil(string) ?? zero
    }

    /// Text the user is still editing needs the difference between "nothing yet" and "zero".
    /// `parse` collapses both to zero, which is fine for stored amounts and wrong for input.
    public static func parseOrNil(_ string: String) -> Decimal? {
        Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))
    }

    public static func fromInt(_ value: Int) -> Decimal {
        parse(String(value))
    }

    public static func format(_ value: Decimal) -> String {
        let rounded = money(value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ""
        #if SKIP
        return formatter.string(from: rounded as NSNumber) ?? "0.00"
        #else
        return formatter.string(from: rounded as NSDecimalNumber) ?? "0.00"
        #endif
    }

    public static func formatCurrency(_ value: Decimal) -> String {
        "€\(format(value))"
    }
}
