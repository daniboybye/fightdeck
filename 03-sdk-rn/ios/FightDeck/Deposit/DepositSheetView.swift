//
// DepositSheetView.swift
// FightDeck
//
// Created by FightDeck on 26.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI
#if FIGHTDECK_DEPOSIT || FIGHTDECK_BOTH
import DepositSDK
#endif

struct DepositSheetView: View {
    @Bindable var state: AppState
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            #if FIGHTDECK_DEPOSIT || FIGHTDECK_BOTH
            DepositSheetContent(state: state, onDismiss: onDismiss)
            #else
            ContentUnavailableView("Deposit not included", systemImage: "puzzlepiece.extension")
            #endif
        }
    }
}

#if FIGHTDECK_DEPOSIT || FIGHTDECK_BOTH
private struct DepositSheetContent: View {
    @Bindable var state: AppState
    let onDismiss: () -> Void

    @State private var depositConfirmed = false
    @State private var layoutMetrics = {
        var metrics = RNSurfaceLayoutMetrics()
        metrics.includesTabBarClearance = false
        return metrics
    }()
    @State private var textInputActive = false

    var body: some View {
        RNSurfaceLayoutReader(metrics: $layoutMetrics) {
            DepositSDKView(
                state: state,
                onDismiss: onDismiss,
                onConfirmed: { depositConfirmed = true },
                layoutMetrics: layoutMetrics,
                textInputActive: textInputActive
            )
        }
        .navigationTitle(depositConfirmed ? "Confirmed" : "Deposit")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(depositConfirmed)
        .onAppear {
            layoutMetrics.includesTabBarClearance = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { _ in
            textInputActive = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidEndEditingNotification)) { _ in
            textInputActive = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            textInputActive = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            textInputActive = false
        }
    }
}
#endif
