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
    case failed(reason: String)
}

// MARK: - Compose (Android)

#if SKIP
public struct DepositComposeEntry: View {
    public let params: DepositParams
    public let theme: ThemeTokens
    public let onResult: @Sendable (DepositResult) -> Void

    public init(
        params: DepositParams,
        theme: ThemeTokens,
        onResult: @escaping @Sendable (DepositResult) -> Void
    ) {
        self.params = params
        self.theme = theme
        self.onResult = onResult
    }

    public var body: some View {
        // The iOS host presents this inside its own navigation stack; the Compose host drops it
        // straight into a destination. Carrying a stack here is what puts the screen's toolbar
        // — its title and its Close button — on the Android side too.
        NavigationStack {
            DepositFlowView(
                params: params,
                theme: theme,
                onResult: onResult
            )
        }
    }
}
#endif
