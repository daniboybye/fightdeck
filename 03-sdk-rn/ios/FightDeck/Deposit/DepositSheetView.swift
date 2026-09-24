//
// DepositSheetView.swift
// FightDeck
//
// Created by FightDeck on 26.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import DepositSDK
import FightDeckRNRuntime
import SwiftUI

struct DepositSheetView: View {
    let state: AppState
    let onDismiss: () -> Void

    @State private var depositConfirmed = false

    var body: some View {
        NavigationStack {
            RNSurfaceView {
                SDKBootstrap.shared.depositHosting.makeViewController(params: params) { result in
                    Task { @MainActor in
                        switch result {
                        case .confirmed:
                            depositConfirmed = true
                        case .completed(let amount):
                            state.deposit(amount: amount)
                            onDismiss()
                        @unknown default:
                            break
                        }
                    }
                }
            } update: {
                SDKBootstrap.shared.depositHosting.update(params: params)
            }
            // Nothing to name once it has happened: the confirmation says so in the middle of the
            // screen, where the eye already is, and a title would only repeat it in the corner.
            .navigationTitle(depositConfirmed ? "" : "Deposit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // The money has already moved by the time the confirmation shows, so that
                // screen leaves through Done only: closing it would spend the deposit twice.
                if !depositConfirmed {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close", systemImage: "xmark", action: onDismiss)
                    }
                }
            }
        }
    }

    private var params: DepositParams {
        DepositParams(themeJSON: ThemeLoader.tokensJSON(), currentBalance: state.balance)
    }
}
