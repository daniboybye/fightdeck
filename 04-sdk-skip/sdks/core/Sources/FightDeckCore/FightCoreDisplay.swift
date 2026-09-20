//
// FightCoreDisplay.swift
// FightCore
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

/// One line of the slip summary. A named type rather than a labelled tuple because Skip
/// transpiles `(label:value:)` to a `Tuple2` whose accessors are `internal` to the module
/// that declared them — reading `.label` from another SDK stops the Kotlin compile dead.
public struct SlipSummaryRow: Identifiable, Sendable {
    public let label: String
    public let value: String

    public var id: String { label }

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

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

    public static func slipSummary(state: SlipState) -> [SlipSummaryRow] {
        var rows = [
            SlipSummaryRow(label: "Total stake", value: Money.formatCurrency(state.totalStake)),
        ]
        if let display = state.combinedOddsDisplay {
            rows.append(SlipSummaryRow(label: "Combined odds", value: Money.format(display)))
        }
        rows.append(SlipSummaryRow(label: "Potential return", value: Money.formatCurrency(state.potentialReturn)))
        rows.append(SlipSummaryRow(label: "Potential profit", value: Money.formatCurrency(state.potentialProfit)))
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
        return formatter.string(from: Money.asNumber(value)) ?? fallback
    }
}
