//
// FightCoreGlue.swift
// FightCoreJava
//
// Created by FightDeck on 09.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightCore
#if os(Android)
import FoundationEssentials
#else
import Foundation
#endif

// jextract maps Int, String, Bool, arrays and imported types, but has no mapping for
// Decimal — the type every amount and every odd in FightCore is written in. Money
// therefore crosses as a decimal string in en_US_POSIX form ("361.11"), parsed back with
// Money.parse on this side. Kotlin turns it into BigDecimal, never into Double.

/// Rounds to two places and formats without a currency symbol.
public func formatMoney(_ amount: String) -> String {
    Money.format(Money.parse(amount))
}

/// Rounds to two places and prefixes the euro sign, matching the iOS balance toolbar.
public func formatCurrency(_ amount: String) -> String {
    Money.formatCurrency(Money.parse(amount))
}

public func formatOdds(_ odds: String) -> String {
    Money.formatOdds(Money.parse(odds))
}

/// Full precision, for the accumulator row where rounding would hide the trap.
public func formatExactOdds(_ odds: String) -> String {
    Money.formatExactOdds(Money.parse(odds))
}

public func decimalToFractional(_ odds: String) -> String {
    OddsEngine.decimalToFractional(Money.parse(odds))
}

public func fractionalToDecimal(_ fractional: String) -> String {
    Money.format(OddsEngine.fractionalToDecimal(fractional))
}

public func impliedProbability(_ odds: String) -> String {
    Money.formatImpliedProbability(Money.parse(odds))
}
