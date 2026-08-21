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
                SlipTabView(state: state, path: $slipPath) {
                    selectedTab = .upcoming
                }
                .tabItem { Label("Slip", systemImage: "list.bullet.rectangle") }
                .tag(Tab.slip)
            }
            .tint(DesignTokens.ColorToken.accent)

            if !state.slip.selections.isEmpty, selectedTab != .slip {
                BetSlipBar(
                    legCount: state.slip.selections.count,
                    potentialReturn: Money.formatCurrency(state.slipState.potentialReturn)
                ) {
                    selectedTab = .slip
                    slipPath = []
                }
                .padding(.bottom, 56)
            }
        }
        .background(DesignTokens.ColorToken.background)
        .task {
            SDKBootstrap.shared.configureOnce()
            await state.bootstrap()
        }
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
