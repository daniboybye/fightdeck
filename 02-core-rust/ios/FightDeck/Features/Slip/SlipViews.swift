//
// SlipViews.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import SwiftUI

struct SlipTabView: View {
    @Bindable var state: AppState
    @Binding var path: [SlipRoute]
    let depositHosting: DepositHosting
    let onBrowseEvents: () -> Void

    var body: some View {
        NavigationStack(path: $path) {
            BetSlipView(
                state: state,
                depositHosting: depositHosting,
                path: $path,
                onBrowseEvents: onBrowseEvents
            )
            .navigationTitle("Bet Slip")
            .navigationDestination(for: SlipRoute.self) { route in
                if route == .deposit {
                    DepositBridgeView(state: state, depositHosting: depositHosting, path: $path)
                        // The deposit flow is a single self-contained task; the tab bar would
                        // invite the user to abandon it half-way.
                        .toolbar(.hidden, for: .tabBar)
                }
            }
        }
    }
}

struct BetSlipView: View {
    @Bindable var state: AppState
    let depositHosting: DepositHosting
    @Binding var path: [SlipRoute]
    let onBrowseEvents: () -> Void
    @State private var stakeText = "10.00"

    var body: some View {
        Group {
            if state.slipStore.slip.selections.isEmpty {
                emptyState
            } else {
                slipContent
            }
        }
        .background(DesignTokens.ColorToken.background)
        .onAppear { stakeText = state.slipStore.slip.stake }
    }

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("No selections yet")
                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            Button("Browse Events", action: onBrowseEvents)
                .buttonStyle(PrimaryCapsuleButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var slipContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                accumulatorNote
                ForEach(Array(state.slipStore.slip.selections.enumerated()), id: \.offset) { _, selection in
                    selectionRow(selection)
                }
                stakeField
                summaryBlock
                validationErrors
                depositSection
                actions
            }
            .padding(DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Layout.tabBarClearance)
        }
    }

    @ViewBuilder
    private var accumulatorNote: some View {
        if state.slipStore.slip.selections.count < FightCoreDisplay.minAccaLegs {
            Text("Add at least two selections to place an accumulator")
                .font(.system(size: DesignTokens.FontSize.caption))
                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
        }
    }

    private func selectionRow(_ selection: SelectionRecord) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(fighterName(selection.fighterId))
                    .font(.system(size: DesignTokens.FontSize.callout))
                Text("vs \(opponentName(for: selection)) · \(eventName(for: selection))")
                    .font(.system(size: DesignTokens.FontSize.caption))
                    .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            }
            Spacer()
            Text(FightCoreDisplay.formatOdds(selection.odds))
                .foregroundStyle(DesignTokens.ColorToken.accent)
            Button {
                state.removeSelection(boutID: selection.boutId, fighterID: selection.fighterId)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            }
            .frame(width: 44, height: 44)
        }
        .cardStyle()
    }

    private var stakeField: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            TextField("Stake", text: $stakeText)
                .keyboardType(.decimalPad)
                .padding(DesignTokens.Spacing.lg)
                .background(DesignTokens.ColorToken.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
                .onChange(of: stakeText) { _, newValue in
                    state.slipStore.setStake(newValue)
                }
            HStack {
                ForEach([5, 10, 25, 50], id: \.self) { chip in
                    Button("€\(chip)") {
                        stakeText = String(format: "%.2f", Double(chip))
                        state.slipStore.setStake(stakeText)
                    }
                    .buttonStyle(ChipButtonStyle())
                }
            }
        }
    }

    private var summaryBlock: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            ForEach(Array(FightCoreDisplay.slipSummary(state: state.slipState).enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.label)
                        .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                    Spacer()
                    Text(row.value)
                }
            }
        }
        .font(.system(size: DesignTokens.FontSize.body))
        .padding(DesignTokens.Spacing.lg)
        .background(DesignTokens.ColorToken.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }

    private var validationErrors: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            ForEach(state.slipState.errors) { error in
                Text(error.displayName.replacingOccurrences(of: "_", with: " "))
                    .foregroundStyle(DesignTokens.ColorToken.negative)
                    .font(.system(size: DesignTokens.FontSize.caption))
            }
        }
    }

    private var depositSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Deposit")
                .font(.system(size: DesignTokens.FontSize.callout, weight: .semibold))
                .foregroundStyle(DesignTokens.ColorToken.textPrimary)
            HStack {
                Text("Balance")
                    .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                Spacer()
                Text(FightCoreDisplay.formatCurrencyAmount(state.slipStore.balance))
                    .contentTransition(.numericText())
            }
            .font(.system(size: DesignTokens.FontSize.body))
            Button("Add funds") { path.append(.deposit) }
                .buttonStyle(PrimaryCapsuleButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            if let message = state.betPlacedMessage {
                Text(message)
                    .font(.system(size: DesignTokens.FontSize.callout, weight: .medium))
                    .foregroundStyle(DesignTokens.ColorToken.positive)
            }
            Button("Place bet") { state.placeBet() }
                .buttonStyle(PrimaryCapsuleButtonStyle())
                .disabled(!state.slipState.errors.isEmpty)
        }
    }

    private func fighterName(_ id: String) -> String {
        if case .loaded(let fighters) = state.fightersState,
           let fighter = fighters.first(where: { $0.id == id }) {
            return fighter.name
        }
        return id
    }

    private func opponentName(for selection: SelectionRecord) -> String {
        guard case .loaded(let events) = state.eventsState else { return "—" }
        for event in events {
            if let bout = event.bouts.first(where: { $0.id == selection.boutId }) {
                let opponentID = bout.redCorner.fighterId == selection.fighterId
                    ? bout.blueCorner.fighterId : bout.redCorner.fighterId
                return fighterName(opponentID)
            }
        }
        return "—"
    }

    private func eventName(for selection: SelectionRecord) -> String {
        guard case .loaded(let events) = state.eventsState,
              let event = events.first(where: { $0.bouts.contains { $0.id == selection.boutId } }) else {
            return "—"
        }
        return event.name
    }
}

private struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: DesignTokens.FontSize.caption, weight: .medium))
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(DesignTokens.ColorToken.surfaceElevated)
            .foregroundStyle(DesignTokens.ColorToken.accent)
            .clipShape(Capsule())
    }
}

struct DepositBridgeView: View {
    @Bindable var state: AppState
    let depositHosting: DepositHosting
    @Binding var path: [SlipRoute]

    var body: some View {
        DepositFlowView(params: depositParams) { result in
            if case .completed(let amount) = result {
                Task { @MainActor in
                    state.deposit(amount: amount)
                    path.removeAll()
                }
            }
        }
    }

    private var depositParams: DepositParams {
        DepositParams(
            accessToken: "demo-token",
            environment: "demo",
            locale: Locale.current.identifier,
            themeJSON: themeJSON,
            currentBalance: Decimal(string: state.slipStore.balance) ?? 0
        )
    }

    private var themeJSON: String {
        DatasetLocator.tokensJSON()
    }
}
