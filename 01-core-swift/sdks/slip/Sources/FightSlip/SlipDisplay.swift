//
// SlipDisplay.swift
// FightSlip
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightCore
#if os(Android)
import FoundationEssentials
#else
import Foundation
#endif

public struct SummaryRow: Sendable, Hashable {
    public let label: String
    public let value: String
}

public enum SlipDisplay {
    /// The label above the legs. The user never picks a mode; the slip says which one it is.
    public static func modeTitle(_ mode: BetMode) -> String {
        mode == .accumulator ? "Accumulator" : "Single"
    }

    /// The summary block under the stake, labels and order included, so neither host decides
    /// which rows a single slip leaves out.
    public static func slipSummary(state: SlipState) -> [SummaryRow] {
        var rows = [SummaryRow(label: "Total stake", value: Money.formatCurrency(state.totalStake))]
        if let display = state.combinedOddsDisplay {
            rows.append(SummaryRow(label: "Combined odds", value: Money.format(display)))
        }
        rows.append(SummaryRow(label: "Potential return", value: Money.formatCurrency(state.potentialReturn)))
        rows.append(SummaryRow(label: "Potential profit", value: Money.formatCurrency(state.potentialProfit)))
        return rows
    }
}
