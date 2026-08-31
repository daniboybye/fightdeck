//
// BalanceToolbar.swift
// FightDeck
//
// Created by FightDeck on 26.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI

struct BalanceToolbarModifier: ViewModifier {
    let state: AppState

    func body(content: Content) -> some View {
        content.toolbar {
            // Every screen in the stack declares this item again, so without a stable id each
            // push reads as a remove plus an insert and the balance fades out and back in.
            ToolbarItem(id: "balance", placement: .topBarTrailing) {
                Menu {
                    Button(action: state.presentDeposit) {
                        Label("Deposit", systemImage: "plus.circle")
                    }
                } label: {
                    Text(Money.formatCurrency(state.balance))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .frame(minHeight: DesignTokens.Layout.minTapTarget)
                        .contentShape(.rect)
                }
                .accessibilityIdentifier("balance-menu")
            }
        }
    }
}

extension View {
    func balanceToolbar(state: AppState) -> some View {
        modifier(BalanceToolbarModifier(state: state))
    }
}
