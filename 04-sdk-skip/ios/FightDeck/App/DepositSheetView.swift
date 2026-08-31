//
// DepositSheetView.swift
// FightDeck
//
// Created by FightDeck on 26.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import SwiftUI
#if FIGHTDECK_DEPOSIT || FIGHTDECK_BOTH
import FightDeckDeposit
#endif

struct DepositSheetView: View {
    @Bindable var state: AppState
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            #if FIGHTDECK_DEPOSIT || FIGHTDECK_BOTH
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
            #else
            ContentUnavailableView("Deposit not included", systemImage: "puzzlepiece.extension")
            #endif
        }
    }

    #if FIGHTDECK_DEPOSIT || FIGHTDECK_BOTH
    private var depositParams: DepositParams {
        DepositParams(
            accessToken: "demo-token",
            environment: "demo",
            locale: Locale.current.identifier,
            themeJSON: ThemeLoader.tokensJSON(),
            currentBalance: state.balance
        )
    }
    #endif
}
