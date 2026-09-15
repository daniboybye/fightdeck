//
// Money.swift
// FightCore
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

// Android takes the ICU-free route through MoneyDigits.swift, which is why the import
// splits here: the Foundation module pulls libFoundationInternationalization and
// lib_FoundationICU into the link whether or not a line of code asks for them, and on
// Android that is 38 MB per ABI of locale tables this app never reads. Apple platforms
// have ICU in the OS, so there the formatters below cost nothing and stay.
#if os(Android)
import FoundationEssentials
#else
import Foundation
#endif

public enum Money {
    #if !os(Android)
    private static let posix = Locale(identifier: "en_US_POSIX")
    private static let moneyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = posix
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ""
        return formatter
    }()

    private static let exactOddsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = posix
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 12
        formatter.groupingSeparator = ""
        return formatter
    }()

    private static let probabilityFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = posix
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 4
        formatter.groupingSeparator = ""
        return formatter
    }()
    #endif

    public static func round(_ value: Decimal, scale: Int = 2) -> Decimal {
        #if os(Android)
        return Decimal(string: fixedPoint(value, scale: scale)) ?? 0
        #else
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, scale, .plain)
        return result
        #endif
    }

    public static func money(_ value: Decimal) -> Decimal {
        round(value, scale: 2)
    }

    public static func parse(_ string: String) -> Decimal {
        #if os(Android)
        // Decimal's own parser is already the POSIX one: a dot for the point, no grouping.
        return Decimal(string: string) ?? 0
        #else
        return Decimal(string: string, locale: posix) ?? 0
        #endif
    }

    public static func format(_ value: Decimal) -> String {
        #if os(Android)
        return fixedPoint(money(value), scale: 2)
        #else
        let rounded = money(value)
        return moneyFormatter.string(from: rounded as NSDecimalNumber) ?? "0.00"
        #endif
    }

    public static func formatCurrency(_ value: Decimal) -> String {
        "€\(format(value))"
    }

    public static func formatOdds(_ odds: Decimal) -> String {
        format(odds)
    }

    public static func formatExactOdds(_ odds: Decimal) -> String {
        #if os(Android)
        return trimmingZeros(fixedPoint(odds, scale: 12))
        #else
        return exactOddsFormatter.string(from: odds as NSDecimalNumber) ?? format(odds)
        #endif
    }

    public static func formatImpliedProbability(_ odds: Decimal) -> String {
        let probability = OddsEngine.impliedProbability(odds)
        #if os(Android)
        return fixedPoint(probability, scale: 4)
        #else
        return probabilityFormatter.string(from: probability as NSDecimalNumber) ?? "0.0000"
        #endif
    }
}
