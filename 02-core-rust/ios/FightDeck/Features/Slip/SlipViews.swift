//
// SlipViews.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightSlip
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
    let state: AppState
    let onBrowseEvents: () -> Void

    @FocusState private var stakeFocused: Bool

    var body: some View {
        Group {
            if !state.slip.selections.isEmpty {
                slipContent
            } else if let message = state.slipStore.snapshot.confirmation {
                placedState(message)
            } else {
                emptyState
            }
        }
        .animation(.smooth(duration: 0.35), value: state.slip.selections.count)
        .animation(.smooth(duration: 0.35), value: state.slipStore.snapshot.confirmation)
        .sensoryFeedback(.success, trigger: state.slipStore.snapshot.confirmation) { _, new in new != nil }
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

    /// Placing a bet empties the slip, so the confirmation has to live where the slip was.
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
            Section(state.slipState.modeTitle) {
                ForEach(state.slip.selections, id: \.self) { selection in
                    selectionRow(selection)
                }
                .onDelete { offsets in
                    let toRemove = offsets.map { state.slip.selections[$0] }
                    for selection in toRemove {
                        state.removeSelection(boutID: selection.boutId, fighterID: selection.fighterId)
                    }
                }
            }
            Section("Stake") {
                stakeField
                stakeChips
            }
            Section {
                ForEach(state.slipState.summaryRows, id: \.label) { row in
                    LabeledContent(row.label, value: row.value)
                }
            }
            if !state.slipState.errors.isEmpty {
                Section {
                    ForEach(state.slipState.errors, id: \.error) { issue in
                        Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(DesignTokens.ColorToken.negative)
                    }
                }
            }
            Section("Deposit") {
                LabeledContent("Balance") {
                    Text(state.slipStore.snapshot.balanceDisplay)
                        .contentTransition(.numericText())
                }
                Button(action: state.presentDeposit) {
                    // Filling the row and giving it a shape is what makes the whole row
                    // tappable; a bare title button only responds on the glyphs themselves.
                    Text("Add funds")
                        .frame(maxWidth: .infinity, minHeight: DesignTokens.Layout.minTapTarget, alignment: .leading)
                        .contentShape(.rect)
                }
            }
        }
        .listStyle(.insetGrouped)
        // safeAreaBar clears the Place bet button; the tab accessory sits below that bar and
        // still needs its own scroll margin or the Deposit rows scroll into its glass slot.
        .safeAreaBar(edge: .bottom) { placeBetBar }
        .contentMargins(.bottom, DesignTokens.Layout.betSlipAccessoryHeight, for: .scrollContent)
        .scrollDismissesKeyboard(.interactively)
    }

    /// An `HStack` rather than `LabeledContent`: the two-line label pushes that layout into
    /// its stacked form, which drops the odds under the fighter instead of out to the edge.
    private func selectionRow(_ selection: SelectionRecord) -> some View {
        let leg = state.catalog.legContext(boutId: selection.boutId, fighterId: selection.fighterId)
        return HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading) {
                Text(leg.fighterName)
                Text(leg.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(selection.odds)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.ColorToken.accent)
        }
    }

    private var stakeField: some View {
        LabeledContent("Amount") {
            TextField(
                "Stake",
                text: Binding(
                    get: { state.slip.stake },
                    set: { state.slipStore.setStake($0) }
                )
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .focused($stakeFocused)
        }
    }

    private var stakeChips: some View {
        PresetChipRow {
            ForEach(stakePresets(), id: \.stake) { preset in
                PresetChipButton(title: preset.title) { state.slipStore.setStake(preset.stake) }
            }
        }
    }

    /// Done sits in this bar, not in a keyboard toolbar: the toolbar draws its pill on top of
    /// whatever the bottom safe area already holds, and leaves a gap above the keyboard.
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
        // The tab accessory already lifts the bar clear of the tab bar, so the ordinary gap is
        // enough; a wider one would double up with the accessory slot.
        .padding(.bottom, DesignTokens.Layout.actionBarGap)
        .animation(.snappy(duration: 0.25), value: stakeFocused)
    }
}