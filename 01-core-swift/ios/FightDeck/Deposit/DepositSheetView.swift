//
// DepositSheetView.swift
// FightDeck
//
// Created by FightDeck on 26.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI

/// Presents deposit as a full-screen sheet so every tab can reach it without a slip-stack push.
struct DepositSheetView: View {
    let state: AppState
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            DepositFlowView(params: depositParams) { result in
                if case .completed(let amount) = result {
                    state.deposit(amount: amount)
                }
                onDismiss()
            }
        }
    }

    private var depositParams: DepositParams {
        DepositParams(currentBalance: state.balance)
    }
}
