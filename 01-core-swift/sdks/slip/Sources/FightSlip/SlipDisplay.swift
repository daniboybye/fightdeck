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

public enum SlipDisplay {
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
