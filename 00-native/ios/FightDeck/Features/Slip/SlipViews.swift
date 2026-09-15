//
// SlipViews.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI

struct SlipTabView: View {
    let state: AppState
    let onBrowseEvents: () -> Void

    var body: some View {
        NavigationStack {
            BetSlipView(state: state, onBrowseEvents: onBrowseEvents)
                .navigationTitle("Bet Slip")
                .balanceToolbar(state: state)
        }
    }
}

struct BetSlipView: View {
    @Bindable var state: AppState
    let onBrowseEvents: () -> Void

    @FocusState private var stakeFocused: Bool

    var body: some View {
        Group {
            if !state.slip.selections.isEmpty {
                slipContent
            } else if let message = state.betPlacedMessage {
                placedState(message)
            } else {
                emptyState
            }
        }
        .animation(.smooth(duration: 0.35), value: state.slip.selections.count)
        .animation(.smooth(duration: 0.35), value: state.betPlacedMessage)
        .sensoryFeedback(.success, trigger: state.betPlacedMessage) { _, new in new != nil }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No selections yet", systemImage: "ticket")
        } description: {
            Text("Pick a winner on any upcoming bout and it lands here.")
        } actions: {
            SecondaryActionButton(title: "Browse Events", action: onBrowseEvents)
        }
    }

    private func placedState(_ message: String) -> some View {
        ContentUnavailableView {
            Label {
                Text("Bet placed")
            } icon: {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(DesignTokens.ColorToken.positive)
                    .symbolEffect(.bounce, options: .nonRepeating)
            }
        } description: {
            Text(message)
        } actions: {
            SecondaryActionButton(title: "Browse Events", action: onBrowseEvents)
        }
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    private var slipContent: some View {
        List {
            selectionsSection
            stakeSection
            summarySection
            errorsSection
            depositSection
        }
        .listStyle(.insetGrouped)
        .safeAreaBar(edge: .bottom) { placeBetBar }
        .contentMargins(.bottom, DesignTokens.Layout.betSlipAccessoryHeight, for: .scrollContent)
        .scrollDismissesKeyboard(.interactively)
    }

    private var selectionsSection: some View {
        Section(betTypeTitle) {
            ForEach(state.slip.selections) { selection in
                selectionRow(selection)
            }
            .onDelete { offsets in
                offsets.map { state.slip.selections[$0].id }.forEach(state.removeSelection)
            }
        }
    }

    private var stakeSection: some View {
        Section("Stake") {
            LabeledContent("Amount") {
                TextField("Stake", value: $state.slip.stake, format: .currency(code: "EUR"))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($stakeFocused)
            }
            PresetChipRow {
                ForEach([5, 10, 25, 50], id: \.self) { chip in
                    PresetChipButton(title: "€\(chip)") { state.slip.stake = .init(chip) }
                }
            }
        }
    }

    private var summarySection: some View {
        Section {
            ForEach(FightCoreDisplay.slipSummary(state: state.slipState), id: \.label) { row in
                LabeledContent(row.label, value: row.value)
            }
        }
    }

    @ViewBuilder
    private var errorsSection: some View {
        if !state.slipState.errors.isEmpty {
            Section {
                ForEach(state.slipState.errors, id: \.self) { error in
                    Label(error.rawValue.displayMethod, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(DesignTokens.ColorToken.negative)
                }
            }
        }
    }

    private var depositSection: some View {
        Section("Deposit") {
            LabeledContent("Balance") {
                Text(Money.formatCurrency(state.balance))
                    .contentTransition(.numericText())
            }
            Button(action: state.presentDeposit) {
                Text("Add funds")
                    .frame(maxWidth: .infinity, minHeight: DesignTokens.Layout.minTapTarget, alignment: .leading)
                    .contentShape(.rect)
            }
        }
    }

    private var placeBetBar: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            PrimaryActionButton(
                title: "Place bet",
                systemImage: "checkmark.seal",
                isEnabled: state.slipState.errors.isEmpty
            ) {
                state.placeBet()
            }
            if stakeFocused {
                KeyboardDoneButton { stakeFocused = false }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.bottom, DesignTokens.Layout.actionBarGap)
        .animation(.snappy(duration: 0.25), value: stakeFocused)
    }

    private var betTypeTitle: String {
        state.slip.mode == .accumulator ? "Accumulator" : "Single"
    }

    private func selectionRow(_ selection: Selection) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading) {
                Text(state.fighter(selection.fighterID)?.name ?? selection.fighterID)
                Text("vs \(opponentName(for: selection)) · \(eventName(for: selection))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(FightCoreDisplay.formatOdds(selection.odds))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.ColorToken.accent)
        }
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
