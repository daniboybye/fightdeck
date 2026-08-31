//
// FightCoreDisplay.swift
// FightCore
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

public enum FightCoreDisplay {
    private static let posix = Locale(identifier: "en_US_POSIX")

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

    public static func formatOdds(_ odds: Decimal) -> String {
        Money.format(odds)
    }

    public static func formatExactOdds(_ odds: Decimal) -> String {
        exactOddsFormatter.string(from: odds as NSDecimalNumber) ?? Money.format(odds)
    }

    public static func formatImpliedProbability(_ odds: Decimal) -> String {
        let probability = OddsEngine.impliedProbability(odds)
        return probabilityFormatter.string(from: probability as NSDecimalNumber) ?? "0.0000"
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
}
