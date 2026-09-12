//
// DepositSheetView.swift
// FightDeck
//
// Created by FightDeck on 26.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import FightDeckDeposit
import SwiftUI

struct DepositSheetView: View {
    @Bindable var state: AppState
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            DepositFlowView(
                params: depositParams,
                theme: ThemeTokens.parse(ThemeLoader.tokensJSON()),
                onResult: { result in
                    if case .completed(let amount) = result {
                        state.deposit(amount: amount)
                    }
                    onDismiss()
                }
            )
        }
    }

    private var depositParams: DepositParams {
        DepositParams(
            accessToken: "demo-token",
            environment: "demo",
            locale: Locale.current.identifier,
            themeJSON: ThemeLoader.tokensJSON(),
            currentBalance: state.balance
        )
    }
}
