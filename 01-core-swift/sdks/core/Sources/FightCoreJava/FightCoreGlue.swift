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

public func decimalToFractional(_ odds: String) -> String {
    OddsEngine.decimalToFractional(Money.parse(odds))
}

public func fractionalToDecimal(_ fractional: String) -> String {
    Money.format(OddsEngine.fractionalToDecimal(fractional))
}

public func impliedProbability(_ odds: String) -> String {
    Money.formatImpliedProbability(Money.parse(odds))
}

// The deposit form asks for a quote on every keystroke, so it comes back as a labelled tuple:
// one JNI call, plain Java values, and no Swift object per keystroke waiting for the collector.

/// The methods in the order the form lists them, as parallel arrays.
public func depositMethods() -> (ids: [String], titles: [String], feeNotes: [String]) {
    let methods = DepositMethod.allCases
    return (ids: methods.map(\.rawValue), titles: methods.map(\.title), feeNotes: methods.map(\.feeNote))
}

public func depositPresets() -> [String] {
    Deposit.presets
}

/// `amount` is two places, ready for `SlipEngine.deposit`; the rest carry the euro sign.
/// `validationMessage` is nil while the amount is acceptable.
public func depositQuote(amountText: String, methodID: String, balance: String) -> (
    amount: String,
    amountDisplay: String,
    feeDisplay: String,
    totalDisplay: String,
    newBalanceDisplay: String,
    validationMessage: String?,
    canConfirm: Bool
) {
    let method = DepositMethod(rawValue: methodID) ?? .card
    let quote = Deposit.quote(amountText: amountText, method: method, balance: Money.parse(balance))
    return (
        amount: Money.format(quote.amount),
        amountDisplay: Money.formatCurrency(quote.amount),
        feeDisplay: Money.formatCurrency(quote.fee),
        totalDisplay: Money.formatCurrency(quote.total),
        newBalanceDisplay: Money.formatCurrency(quote.newBalance),
        validationMessage: quote.validationMessage,
        canConfirm: quote.canConfirm
    )
}
