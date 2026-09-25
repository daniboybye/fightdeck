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
    let state: AppState
    let onBrowseEvents: @MainActor @Sendable () -> Void

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
    let onBrowseEvents: @MainActor @Sendable () -> Void
    let onDeposit: @MainActor @Sendable () -> Void

    var body: some View {
        // The SDK's callbacks are `@Sendable` because they also have to cross into Kotlin, so
        // they arrive with no actor. Everything they touch here is main-actor state, which is
        // what the hop is for.
        BetSlipRootView(
            store: state.slipStore,
            display: display,
            onDeposit: { Task { @MainActor in onDeposit() } },
            onBrowseEvents: { Task { @MainActor in onBrowseEvents() } }
        )
    }

    /// Built from the lists as they stand on this pass, so the rows pick up the names once the
    /// catalogue finishes loading.
    private var display: CatalogSlipDisplay {
        var events: [Event] = []
        var fighters: [Fighter] = []
        if case .loaded(let loaded) = state.eventsState { events = loaded }
        if case .loaded(let loaded) = state.fightersState { fighters = loaded }
        return CatalogSlipDisplay(events: events, fighters: fighters)
    }
}
