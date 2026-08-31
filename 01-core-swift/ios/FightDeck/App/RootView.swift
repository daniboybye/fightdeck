//
// RootView.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightCore
import SwiftUI

struct RootView: View {
    @State private var state = AppState()
    @State private var upcomingPath: [EventsRoute] = []
    @State private var pastPath: [EventsRoute] = []
    @State private var selectedTab = AppTab.upcoming

    private enum AppTab: Hashable {
        case upcoming
        case past
        case slip
    }

    private var showsBetSlipAccessory: Bool {
        !state.slip.selections.isEmpty && !state.isPresentingDeposit
    }

    var body: some View {
        Group {
            switch state.bootstrapState {
            case .loading:
                bootstrapView(message: "Starting…", showsProgress: true)
            case .failed(let message):
                bootstrapView(message: message, showsProgress: false) {
                    Task { await state.retryBootstrap() }
                }
            case .ready:
                mainTabs
            }
        }
        .task { await state.bootstrap() }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            Tab("Upcoming", systemImage: "calendar", value: AppTab.upcoming) {
                EventsTabView(state: state, path: $upcomingPath, mode: .upcoming)
            }
            Tab("Past", systemImage: "trophy", value: AppTab.past) {
                EventsTabView(state: state, path: $pastPath, mode: .past)
            }
            Tab("Slip", systemImage: "list.bullet.rectangle", value: AppTab.slip) {
                SlipTabView(state: state) {
                    selectedTab = .upcoming
                }
            }
        }
        .tint(DesignTokens.ColorToken.accent)
        .tabBarMinimizeBehavior(.never)
        .tabViewBottomAccessory(isEnabled: showsBetSlipAccessory) {
            BetSlipAccessory(
                legCount: state.slip.selections.count,
                potentialReturn: Money.formatCurrency(state.slipState.potentialReturn)
            ) {
                selectedTab = .slip
            }
        }
        .animation(.none, value: showsBetSlipAccessory)
        .sheet(isPresented: $state.isPresentingDeposit) {
            DepositSheetView(state: state) {
                state.isPresentingDeposit = false
            }
        }
    }

    private func bootstrapView(
        message: String,
        showsProgress: Bool,
        retry: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            if showsProgress {
                ProgressView()
            }
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if let retry {
                Button("Retry", action: retry)
                    .buttonStyle(.glassProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }
}

private struct BetSlipAccessory: View {
    let legCount: Int
    let potentialReturn: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label("\(legCount) selection\(legCount == 1 ? "" : "s")", systemImage: "ticket")
                    .labelStyle(.titleAndIcon)
                Spacer()
                Text("Return \(potentialReturn)")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity)
            .frame(height: DesignTokens.Layout.betSlipAccessoryHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
