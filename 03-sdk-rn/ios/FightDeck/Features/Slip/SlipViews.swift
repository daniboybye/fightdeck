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
        BetslipParams(
            balance: state.balance,
            stake: state.slip.stake,
            selections: state.slip.selections.compactMap(leg),
            betPlacedMessage: state.betPlacedMessage ?? ""
        )
    }

    /// Names each pick from the catalogue the host already has in memory.
    private func leg(_ selection: Selection) -> BetslipSelection? {
        guard case .loaded(let events) = state.eventsState else { return nil }
        for event in events {
            guard let bout = event.bouts.first(where: { $0.id == selection.boutID }) else { continue }
            let picked = bout.redCorner.fighterId == selection.fighterID ? bout.redCorner : bout.blueCorner
            let opponent = picked.fighterId == bout.redCorner.fighterId ? bout.blueCorner : bout.redCorner
            return BetslipSelection(
                boutID: bout.id,
                fighterID: selection.fighterID,
                opponentID: opponent.fighterId,
                odds: selection.odds,
                fighterName: picked.name,
                opponentName: opponent.name,
                eventName: event.name
            )
        }
        return nil
    }
}
