//
// FightCoreDisplay.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

enum FightCoreDisplay {
    private static let probabilityFormatter = decimalFormatter(minimumFractionDigits: 4, maximumFractionDigits: 4)

    private static func decimalFormatter(minimumFractionDigits: Int, maximumFractionDigits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.groupingSeparator = ""
        return formatter
    }

    static func formatOdds(_ odds: Decimal) -> String {
        Money.format(odds)
    }

    static func formatImpliedProbability(_ odds: Decimal) -> String {
        let probability = OddsEngine.impliedProbability(odds)
        return probabilityFormatter.string(from: probability as NSDecimalNumber) ?? "0.0000"
    }
}
