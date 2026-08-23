//
// SlipViews.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import FightCore
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
            if state.slip.selections.isEmpty {
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
                ForEach(state.slip.selections) { selection in
                    selectionRow(selection)
                }
                .onDelete { offsets in
                    offsets.map { state.slip.selections[$0].id }.forEach(state.removeSelection)
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
                    ForEach(state.slipState.errors, id: \.self) { error in
                        Label(error.rawValue.displayMethod, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(DesignTokens.ColorToken.negative)
                    }
                }
            }
            Section("Deposit") {
                LabeledContent("Balance") {
                    Text(Money.formatCurrency(state.balance))
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
        state.slip.mode == .accumulator ? "Accumulator" : "Single"
    }

    private func selectionRow(_ selection: Selection) -> some View {
        LabeledContent {
            Text(FightCoreDisplay.formatOdds(selection.odds))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.ColorToken.accent)
        } label: {
            VStack(alignment: .leading) {
                Text(state.fighter(selection.fighterID)?.name ?? selection.fighterID)
                Text("vs \(opponentName(for: selection)) · \(eventName(for: selection))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var stakeField: some View {
        LabeledContent("Amount") {
            TextField("Stake", value: $state.slip.stake, format: .currency(code: "EUR"))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($stakeFocused)
        }
    }

    private var stakeChips: some View {
        HStack {
            ForEach([5, 10, 25, 50], id: \.self) { chip in
                Button("€\(chip)") { state.slip.stake = Decimal(chip) }
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

    private func opponentName(for selection: Selection) -> String {
        guard case .loaded(let events) = state.eventsState else { return "—" }
        for event in events {
            if let bout = event.bouts.first(where: { $0.id == selection.boutID }) {
                let opponentID = bout.redCorner.fighterId == selection.fighterID
                    ? bout.blueCorner.fighterId : bout.redCorner.fighterId
                return state.fighter(opponentID)?.name ?? opponentID
            }
        }
        return "—"
    }

    private func eventName(for selection: Selection) -> String {
        guard case .loaded(let events) = state.eventsState,
              let event = events.first(where: { $0.bouts.contains { $0.id == selection.boutID } }) else {
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
            currentBalance: state.balance
        )
    }

    private var themeJSON: String {
        DatasetLocator.tokensJSON()
    }
}
