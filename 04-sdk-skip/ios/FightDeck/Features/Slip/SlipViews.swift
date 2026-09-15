//
// SlipViews.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckBetslip
import FightDeckCore
import SwiftUI

struct SlipTabView: View {
    @Bindable var state: AppState
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

    // Built in `init`, not in `onAppear`. An optional store leaves the `if let` branch empty
    // on first render, and SwiftUI drops lifecycle modifiers attached to an empty view — so
    // the store was never created and the tab stayed blank.
    @State private var store: BetSlipStore

    init(
        state: AppState,
                onBrowseEvents: @escaping () -> Void,
        onDeposit: @escaping @MainActor @Sendable () -> Void
    ) {
        self.state = state
        self.onBrowseEvents = onBrowseEvents
        self.onDeposit = onDeposit
        _store = State(initialValue: BetSlipStore(
            fightCore: state.fightCore,
            slip: state.slip,
            balance: state.balance
        ))
    }

    var body: some View {
        BetSlipRootView(
            store: store,
            display: HostSlipDisplayContext(state: state),
            theme: BetslipTheme.parse(ThemeLoader.tokensJSON()),
            onDeposit: { onDeposit() },
            onBrowseEvents: onBrowseEvents,
            onHostSync: { slip, balance, message in
                state.applySdkSlip(slip, balance: balance, betPlacedMessage: message)
            }
        )
        .onChange(of: state.slip) { _, newSlip in
            store.slip = newSlip
        }
        .onChange(of: state.balance) { _, newBalance in
            store.balance = newBalance
        }
        // The host clears the confirmation when the slip changes from another tab; without
        // pushing that back the SDK keeps showing "bet placed" over an empty slip.
        .onChange(of: state.betPlacedMessage) { _, message in
            store.betPlacedMessage = message
        }
    }
}

@MainActor
final class HostSlipDisplayContext: SlipDisplayContext {
    private let state: AppState

    init(state: AppState) {
        self.state = state
    }

    func fighterName(id: String) -> String {
        guard case .loaded(let fighters) = state.fightersState,
              let fighter = fighters.first(where: { $0.id == id }) else {
            return id
        }
        return fighter.name
    }

    func opponentName(for selection: Selection) -> String {
        guard case .loaded(let events) = state.eventsState else { return "—" }
        for event in events {
            if let bout = event.bouts.first(where: { $0.id == selection.boutID }) {
                let opponentID = bout.redCorner.fighterId == selection.fighterID
                    ? bout.blueCorner.fighterId : bout.redCorner.fighterId
                return fighterName(id: opponentID)
            }
        }
        return "—"
    }

    func eventName(for selection: Selection) -> String {
        guard case .loaded(let events) = state.eventsState,
              let event = events.first(where: { $0.bouts.contains { $0.id == selection.boutID } }) else {
            return "—"
        }
        return event.name
    }
}
