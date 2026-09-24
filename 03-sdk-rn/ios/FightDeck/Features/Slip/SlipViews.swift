//
// SlipViews.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import BetslipSDK
import FightDeckRNRuntime
import SwiftUI

struct SlipTabView: View {
    let state: AppState
    let onBrowseEvents: () -> Void

    var body: some View {
        NavigationStack {
            BetslipBridgeView(
                state: state,
                onBrowseEvents: onBrowseEvents,
                onDeposit: state.presentDeposit
            )
            .navigationTitle("Bet Slip")
            .balanceToolbar(state: state)
        }
    }
}

struct BetslipBridgeView: View {
    let state: AppState
    let onBrowseEvents: () -> Void
    let onDeposit: @MainActor @Sendable () -> Void

    var body: some View {
        RNSurfaceView {
            SDKBootstrap.shared.betslipHosting.makeViewController(params: params) { result in
                Task { @MainActor in
                    switch result {
                    case .updated(let slipJSON):
                        state.applySlipJSON(slipJSON)
                    case .browseEvents:
                        onBrowseEvents()
                    case .deposit:
                        onDeposit()
                    case .placed(let message, let slipJSON, let balance):
                        state.placeBetFromSDK(message: message, slipJSON: slipJSON, balanceString: balance)
                    @unknown default:
                        break
                    }
                }
            }
        } update: {
            SDKBootstrap.shared.betslipHosting.update(params: params)
        }
    }

    private var params: BetslipParams {
        // Sorted, because the encoder's key order changes from one call to the next, and the
        // same slip spelled differently reads as a change the adapter has to push.
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let slipJSON = (try? encoder.encode(SlipPayload(from: state.slip))).flatMap {
            String(data: $0, encoding: .utf8)
        } ?? "{}"
        let eventsURL = DatasetLocator.datasetRoot().appendingPathComponent("events.json")
        let eventsJSON = (try? String(contentsOf: eventsURL, encoding: .utf8)) ?? "{\"events\":[]}"
        return BetslipParams(
            themeJSON: ThemeLoader.tokensJSON(),
            balance: state.balance,
            slipJSON: slipJSON,
            eventsJSON: eventsJSON,
            betPlacedMessage: state.betPlacedMessage ?? ""
        )
    }
}
