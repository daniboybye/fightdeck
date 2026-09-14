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
                    Text(FightCoreDisplay.formatCurrencyAmount(state.slipStore.balance))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .contentShape(.rect)
                }
                .frame(minHeight: DesignTokens.Layout.minTapTarget)
                .glassEffect(.regular.interactive(), in: .capsule)
                .accessibilityIdentifier("balance-menu")
            }
            // Tabs own separate navigation bars, so switching tab rebuilds the bar's shared glass
            // and every item in it blinks. Carrying our own glass keeps the balance still.
            .sharedBackgroundVisibility(.hidden)
        }
    }
}

extension View {
    func balanceToolbar(state: AppState) -> some View {
        modifier(BalanceToolbarModifier(state: state))
    }
}
