//
// Money.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

enum Money {
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
        Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    static func format(_ value: Decimal) -> String {
        let rounded = money(value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ""
        return formatter.string(from: rounded as NSDecimalNumber) ?? "0.00"
    }

    static func formatCurrency(_ value: Decimal) -> String {
        "€\(format(value))"
    }
}
