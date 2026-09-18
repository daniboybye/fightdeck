//
// DepositContract.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

/// The deposit feature's input and output. The SDK approaches hand exactly these two types
/// across their runtime boundary; the baseline writes the screen by hand behind them.
struct DepositParams: Sendable {
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
