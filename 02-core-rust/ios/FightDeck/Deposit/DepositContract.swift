//
// DepositContract.swift
// FightDeck
//
// The deposit feature's input and output. The SDK approaches hand exactly these two types
// across their runtime boundary; this app writes the screen by hand behind them.
//

import Foundation

struct DepositParams: Sendable {
    let accessToken: String
    let environment: String
    let locale: String
    let themeJSON: String
    let currentBalance: Decimal
}

enum DepositResult: Sendable {
    case completed(amount: Decimal)
    case cancelled
    case failed(reason: String)
}

/// `@Sendable` so an SDK-backed host can carry it across a runtime boundary, `@MainActor`
/// because every implementation resolves it while driving UI.
typealias DepositResultHandler = @MainActor @Sendable (DepositResult) -> Void
