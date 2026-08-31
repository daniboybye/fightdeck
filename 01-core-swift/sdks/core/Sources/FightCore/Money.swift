//
// Money.swift
// FightCore
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

public enum Money {
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

    public static func round(_ value: Decimal, scale: Int = 2) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, scale, .plain)
        return result
    }

    public static func money(_ value: Decimal) -> Decimal {
        round(value, scale: 2)
    }

    public static func parse(_ string: String) -> Decimal {
        Decimal(string: string, locale: posix) ?? 0
    }

    public static func format(_ value: Decimal) -> String {
        let rounded = money(value)
        return moneyFormatter.string(from: rounded as NSDecimalNumber) ?? "0.00"
    }

    public static func formatCurrency(_ value: Decimal) -> String {
        "€\(format(value))"
    }
}
