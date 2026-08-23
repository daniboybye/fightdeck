//
// RootView.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import FightCore
import SwiftUI

struct RootView: View {
    @State private var state = AppState()
    @State private var upcomingPath: [EventsRoute] = []
    @State private var pastPath: [EventsRoute] = []
    @State private var slipPath: [SlipRoute] = []

    @State private var selectedTab = AppTab.upcoming
    private let depositHosting: DepositHosting = NativeDepositHosting()

    private enum AppTab: Hashable {
        case upcoming
        case past
        case slip
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Upcoming", systemImage: "calendar", value: AppTab.upcoming) {
                EventsTabView(state: state, path: $upcomingPath, mode: .upcoming)
            }
            Tab("Past", systemImage: "trophy", value: AppTab.past) {
                EventsTabView(state: state, path: $pastPath, mode: .past)
            }
            Tab("Slip", systemImage: "list.bullet.rectangle", value: AppTab.slip) {
                SlipTabView(state: state, path: $slipPath, depositHosting: depositHosting) {
                    selectedTab = .upcoming
                }
            }
        }
        .tint(DesignTokens.ColorToken.accent)
        .tabBarMinimizeBehavior(.onScrollDown)
        // The bar is a shortcut into the slip while you are picking odds, so it belongs to
        // the tab you pick odds on. As a tab view accessory it also inflates the safe area,
        // which is what keeps it off the last row of every scroll view.
        .tabViewBottomAccessory(isEnabled: showsSlipAccessory) {
            BetSlipAccessory(
                legCount: state.slip.selections.count,
                potentialReturn: Money.formatCurrency(state.slipState.potentialReturn)
            ) {
                selectedTab = .slip
                slipPath = []
            }
        }
        .task { await state.bootstrap() }
    }

    private var showsSlipAccessory: Bool {
        selectedTab == .upcoming && !state.slip.selections.isEmpty
    }
}

private struct BetSlipAccessory: View {
    let legCount: Int
    let potentialReturn: String
    let action: () -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        Button(action: action) {
            HStack {
                Label("\(legCount) selection\(legCount == 1 ? "" : "s")", systemImage: "ticket")
                    .labelStyle(.titleAndIcon)
                if placement != .inline {
                    Spacer()
                    Text("Return \(potentialReturn)")
                        .fontWeight(.semibold)
                }
            }
            .font(.subheadline)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
