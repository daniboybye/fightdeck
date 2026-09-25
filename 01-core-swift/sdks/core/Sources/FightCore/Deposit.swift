//
// Deposit.swift
// FightCore
//
// Created by FightDeck on 24.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

#if os(Android)
import FoundationEssentials
#else
import Foundation
#endif

public enum DepositMethod: String, CaseIterable, Identifiable, Sendable {
    case card
    case bank
    case wallet

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .card: "Card"
        case .bank: "Bank transfer"
        case .wallet: "Wallet"
        }
    }

    public var feeNote: String {
        switch self {
        case .card: "Instant · 0% fee"
        case .bank: "1–2 days · 0% fee"
        case .wallet: "Instant · 1% fee"
        }
    }

    public var feeRate: Decimal {
        switch self {
        case .card, .bank: 0
        case .wallet: Decimal(string: "0.01")!
        }
    }
}

public struct DepositQuote: Sendable {
    public let amount: Decimal
    public let fee: Decimal
    /// The fee is charged on top of the deposit, not taken out of it.
    public let total: Decimal
    public let newBalance: Decimal
    /// Nil while the field is empty: nothing typed is not yet a mistake.
    public let validationMessage: String?
    public let canConfirm: Bool
}

/// Deposit rules: the limits, the fee each method charges and how that fee rounds. They were
/// written four times — once per deposit screen, in two languages — before they moved here.
public enum Deposit {
    /// The amounts offered as one-tap chips under the field.
    public static let presets = ["10", "25", "50", "100"]
    public static let minimum = Decimal(10)
    public static let maximum = Decimal(2_000)

    /// The amount is rounded before anything else reads it, so the limits judge — and the fee
    /// is charged on — the figure that will actually reach the balance. A decimal comma reads
    /// as a point: that is what the number pad types in a comma locale. A character map rather
    /// than `replacingOccurrences`, which Android would pay ICU for.
    public static func quote(amountText: String, method: DepositMethod, balance: Decimal) -> DepositQuote {
        let amount = Money.money(Money.parse(String(amountText.map { $0 == "," ? "." : $0 })))
        let fee = Money.money(amount * method.feeRate)
        let validationMessage: String? = if amountText.isEmpty {
            nil
        } else if amount < minimum {
            "Minimum deposit is €10"
        } else if amount > maximum {
            "Maximum deposit is €2,000"
        } else {
            nil
        }
        return DepositQuote(
            amount: amount,
            fee: fee,
            total: amount + fee,
            newBalance: balance + amount,
            validationMessage: validationMessage,
            canConfirm: !amountText.isEmpty && validationMessage == nil
        )
    }
}
