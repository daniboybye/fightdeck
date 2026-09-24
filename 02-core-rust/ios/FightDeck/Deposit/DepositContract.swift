//
// DepositContract.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

/// Amounts are decimal strings, the form the Rust core reads and writes them in.
struct DepositParams: Sendable {
    let currentBalance: String
}

enum DepositResult: Sendable {
    case completed(amount: String)
    case cancelled
    case failed(reason: String)
}

typealias DepositResultHandler = @MainActor @Sendable (DepositResult) -> Void
