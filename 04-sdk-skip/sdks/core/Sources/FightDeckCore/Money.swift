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

    /// The one place the platforms' number bridging differs: Skip maps `Decimal` onto
    /// `java.math.BigDecimal`, which is already an `NSNumber`, while Foundation wants the
    /// `NSDecimalNumber` wrapper. Everything that formats or reads a `Decimal` goes through
    /// here, so the `#if` is written once instead of at each call.
    public static func asNumber(_ value: Decimal) -> NSNumber {
        #if SKIP
        return value as NSNumber
        #else
        return NSDecimalNumber(decimal: value)
        #endif
    }

    public static func format(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ""
        return formatter.string(from: asNumber(money(value))) ?? "0.00"
    }

    public static func formatCurrency(_ value: Decimal) -> String {
        "€\(format(value))"
    }
}
