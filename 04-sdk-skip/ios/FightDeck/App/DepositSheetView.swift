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
    let state: AppState
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            DepositFlowView(
                params: DepositParams(currentBalance: state.slipStore.balance),
                theme: ThemeTokens.defaults,
                onResult: { result in
                    Task { @MainActor in
                        if case .completed(let amount) = result {
                            state.slipStore.deposit(amount: amount)
                        }
                        onDismiss()
                    }
                }
            )
        }
    }
}
