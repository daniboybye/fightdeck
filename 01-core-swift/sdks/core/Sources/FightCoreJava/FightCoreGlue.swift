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

public final class DepositMethodBridge {
    public let id: String
    public let title: String
    public let feeNote: String

    init(_ method: DepositMethod) {
        id = method.rawValue
        title = method.title
        feeNote = method.feeNote
    }
}

public final class DepositQuoteBridge {
    /// Two places, ready for `SlipEngine.deposit`.
    public let amount: String
    public let amountDisplay: String
    public let feeDisplay: String
    public let totalDisplay: String
    public let newBalanceDisplay: String
    /// Empty while the amount is acceptable: jextract carries no optionals.
    public let validationMessage: String
    /// `confirmable` rather than `canConfirm`: jextract names a Bool getter `is…`.
    public let confirmable: Bool

    init(_ quote: DepositQuote) {
        amount = Money.format(quote.amount)
        amountDisplay = Money.formatCurrency(quote.amount)
        feeDisplay = Money.formatCurrency(quote.fee)
        totalDisplay = Money.formatCurrency(quote.total)
        newBalanceDisplay = Money.formatCurrency(quote.newBalance)
        validationMessage = quote.validationMessage ?? ""
        confirmable = quote.canConfirm
    }
}

public func depositMethods() -> [DepositMethodBridge] {
    DepositMethod.allCases.map(DepositMethodBridge.init)
}

public func depositPresets() -> [String] {
    Deposit.presets
}

public func depositQuote(amountText: String, methodID: String, balance: String) -> DepositQuoteBridge {
    let method = DepositMethod(rawValue: methodID) ?? .card
    return DepositQuoteBridge(
        Deposit.quote(amountText: amountText, method: method, balance: Money.parse(balance))
    )
}
