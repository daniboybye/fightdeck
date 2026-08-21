//
// RootView.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import SwiftUI

struct RootView: View {
    @State private var state = AppState()
    @State private var upcomingPath: [EventsRoute] = []
    @State private var pastPath: [EventsRoute] = []
    @State private var slipPath: [SlipRoute] = []

    @State private var selectedTab = Tab.upcoming
    private let depositHosting: DepositHosting = NativeDepositHosting()

    private enum Tab: Hashable {
        case upcoming
        case past
        case slip
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                EventsTabView(state: state, path: $upcomingPath, mode: .upcoming)
                    .tabItem { Label("Upcoming", systemImage: "calendar") }
                    .tag(Tab.upcoming)
                EventsTabView(state: state, path: $pastPath, mode: .past)
                    .tabItem { Label("Past", systemImage: "trophy") }
                    .tag(Tab.past)
                SlipTabView(state: state, path: $slipPath, depositHosting: depositHosting) {
                    selectedTab = .upcoming
                }
                .tabItem { Label("Slip", systemImage: "list.bullet.rectangle") }
                .tag(Tab.slip)
            }
            .tint(DesignTokens.ColorToken.accent)

            // The bar exists to get you to the slip, so it is pure noise while the slip is
            // already on screen — and it would cover the Place bet button.
            if !state.slipStore.slip.selections.isEmpty, selectedTab != .slip {
                BetSlipBar(
                    legCount: state.slipStore.slip.selections.count,
                    potentialReturn: FightCoreDisplay.formatCurrencyAmount(state.slipState.potentialReturn)
                ) {
                    selectedTab = .slip
                    slipPath = []
                }
                .padding(.bottom, 56)
            }
        }
        .background(DesignTokens.ColorToken.background)
        .task { await state.bootstrap() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle(isOn: $state.simulateNetworkFailure) {
                    Image(systemName: "wifi.slash")
                }
                .labelsHidden()
            }
        }
    }
}
