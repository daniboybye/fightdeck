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

    @FocusState private var stakeFocused: Bool

    var body: some View {
        Group {
            if state.slipStore.slip.selections.isEmpty {
                emptyState
            } else {
                slipContent
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No selections yet", systemImage: "ticket")
        } description: {
            Text("Pick a winner on any upcoming bout and it lands here.")
        } actions: {
            Button("Browse Events", action: onBrowseEvents)
                .buttonStyle(.glassProminent)
        }
    }

    private var slipContent: some View {
        List {
            Section(betTypeTitle) {
                ForEach(Array(state.slipStore.slip.selections.enumerated()), id: \.offset) { _, selection in
                    selectionRow(selection)
                }
                .onDelete { offsets in
                    for index in offsets {
                        let selection = state.slipStore.slip.selections[index]
                        state.removeSelection(boutID: selection.boutId, fighterID: selection.fighterId)
                    }
                }
            }
            Section("Stake") {
                stakeField
                stakeChips
            }
            Section {
                ForEach(Array(FightCoreDisplay.slipSummary(state: state.slipState).enumerated()), id: \.offset) { _, row in
                    LabeledContent(row.label, value: row.value)
                }
            }
            if !state.slipState.errors.isEmpty {
                Section {
                    ForEach(state.slipState.errors) { error in
                        Label(error.displayName.displayMethod, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(DesignTokens.ColorToken.negative)
                    }
                }
            }
            Section("Deposit") {
                LabeledContent("Balance") {
                    Text(FightCoreDisplay.formatCurrencyAmount(state.slipStore.balance))
                        .contentTransition(.numericText())
                }
                Button("Add funds") { path.append(.deposit) }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) { placeBetBar }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { stakeFocused = false }
            }
        }
    }

    /// One leg is a single, two or more is an accumulator. The user never picks — the slip
    /// just says which one it currently is.
    private var betTypeTitle: String {
        state.slipStore.slip.mode == .accumulator ? "Accumulator" : "Single"
    }

    private func selectionRow(_ selection: SelectionRecord) -> some View {
        LabeledContent {
            Text(FightCoreDisplay.formatOdds(selection.odds))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.ColorToken.accent)
        } label: {
            VStack(alignment: .leading) {
                Text(fighterName(selection.fighterId))
                Text("vs \(opponentName(for: selection)) · \(eventName(for: selection))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var stakeField: some View {
        LabeledContent("Amount") {
            TextField(
                "Stake",
                text: Binding(
                    get: { state.slipStore.slip.stake },
                    set: { state.slipStore.setStake($0) }
                )
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .focused($stakeFocused)
        }
    }

    private var stakeChips: some View {
        HStack {
            ForEach([5, 10, 25, 50], id: \.self) { chip in
                Button("€\(chip)") { state.slipStore.setStake(String(format: "%.2f", Double(chip))) }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .frame(maxWidth: .infinity)
            }
        }
        .tint(DesignTokens.ColorToken.accent)
    }

    private var placeBetBar: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            if let message = state.betPlacedMessage {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(DesignTokens.ColorToken.positive)
            }
            Button {
                state.placeBet()
            } label: {
                Text("Place bet")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(DesignTokens.ColorToken.accent)
            .disabled(!state.slipState.errors.isEmpty)
        }
        .padding(DesignTokens.Spacing.lg)
        .background(.bar)
    }

    private func fighterName(_ id: String) -> String {
        state.fighter(id)?.name ?? id
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
