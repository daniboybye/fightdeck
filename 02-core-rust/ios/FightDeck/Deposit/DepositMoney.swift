//
// DepositMoney.swift
// FightDeck
//
// Deposit UI formatting — not part of FightCore; uses Decimal locally.
//

import Foundation

enum DepositMoney {
    static func parse(_ string: String) -> Decimal {
        Decimal(string: string) ?? 0
    }

    static func money(_ value: Decimal) -> Decimal {
        var input = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, 2, .plain)
        return rounded
    }

    static func formatCurrency(_ value: Decimal) -> String {
        FightCoreDisplay.formatCurrencyAmount(NSDecimalNumber(decimal: value).stringValue)
    }
}
