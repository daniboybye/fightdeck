//
// Money.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

enum Money {
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

    static func round(_ value: Decimal, scale: Int = 2) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, scale, .plain)
        return result
    }

    static func money(_ value: Decimal) -> Decimal {
        round(value, scale: 2)
    }

    static func parse(_ string: String) -> Decimal {
        Decimal(string: string, locale: posix) ?? 0
    }

    static func format(_ value: Decimal) -> String {
        moneyFormatter.string(from: money(value) as NSDecimalNumber) ?? "0.00"
    }

    static func formatCurrency(_ value: Decimal) -> String {
        "€\(format(value))"
    }
}
