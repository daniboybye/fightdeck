//
// FightCoreDisplay.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

enum FightCoreDisplay {
    private static let exactOddsFormatter = decimalFormatter(minimumFractionDigits: 0, maximumFractionDigits: 12)
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

    static func formatExactOdds(_ odds: Decimal) -> String {
        exactOddsFormatter.string(from: odds as NSDecimalNumber) ?? Money.format(odds)
    }

    static func formatImpliedProbability(_ odds: Decimal) -> String {
        let probability = OddsEngine.impliedProbability(odds)
        return probabilityFormatter.string(from: probability as NSDecimalNumber) ?? "0.0000"
    }

    static func slipSummary(state: SlipState) -> [(label: String, value: String)] {
        var rows: [(String, String)] = [
            ("Total stake", Money.formatCurrency(state.totalStake)),
        ]
        if let display = state.combinedOddsDisplay {
            rows.append(("Combined odds", Money.format(display)))
        }
        rows.append(("Potential return", Money.formatCurrency(state.potentialReturn)))
        rows.append(("Potential profit", Money.formatCurrency(state.potentialProfit)))
        return rows
    }
}
