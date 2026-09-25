//
// DepositHosting.swift
// FightDeckDeposit
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import SwiftUI

public struct DepositParams: Sendable {
    public let currentBalance: Decimal

    public init(currentBalance: Decimal) {
        self.currentBalance = currentBalance
    }
}

public enum DepositResult: Sendable {
    case completed(amount: Decimal)
    case cancelled
}

/// The deposit flow inside the navigation stack its title and Close button need. Both hosts
/// mount this one view: the iOS sheet and the Android destination used to add the stack
/// themselves — the iOS host in its own code, Android through an entry type that existed only
/// for that — and a toolbar with no bar to live in renders nothing at all.
public struct DepositScreen: View {
    let params: DepositParams
    let onResult: @Sendable (DepositResult) -> Void

    public init(params: DepositParams, onResult: @escaping @Sendable (DepositResult) -> Void) {
        self.params = params
        self.onResult = onResult
    }

    public var body: some View {
        NavigationStack {
            DepositFlowView(params: params, onResult: onResult)
        }
    }
}
