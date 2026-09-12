//
// DepositSheetView.swift
// FightDeck
//
// Created by FightDeck on 26.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import DepositSDK
import SwiftUI

struct DepositSheetView: View {
    @Bindable var state: AppState
    let onDismiss: () -> Void

    @State private var depositConfirmed = false
    @State private var textInputActive = false
    @State private var layoutMetrics = RNSurfaceLayoutMetrics()

    var body: some View {
        NavigationStack {
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
            .tracksTextInput($textInputActive)
        }
    }
}
