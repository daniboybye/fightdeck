//
// FightCoreDisplay.swift
// FightCore
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import Foundation

public enum FightCoreDisplay {
    public static func formatOdds(_ odds: Decimal) -> String {
        Money.format(odds)
    }

    public static func formatExactOdds(_ odds: Decimal) -> String {
        formatWithFormatter(odds, minimumFractionDigits: 0, maximumFractionDigits: 12, fallback: Money.format(odds))
    }

    public static func formatImpliedProbability(_ odds: Decimal) -> String {
        let probability = OddsEngine.impliedProbability(odds)
        return formatWithFormatter(probability, minimumFractionDigits: 4, maximumFractionDigits: 4, fallback: "0.0000")
    }

    public static func slipSummary(state: SlipState) -> [(label: String, value: String)] {
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

    private static func formatWithFormatter(
        _ value: Decimal,
        minimumFractionDigits: Int,
        maximumFractionDigits: Int,
        fallback: String
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.groupingSeparator = ""
        #if SKIP
        return formatter.string(from: value as NSNumber) ?? fallback
        #else
        return formatter.string(from: value as NSDecimalNumber) ?? fallback
        #endif
    }
}
