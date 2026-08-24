//
// SlipViews.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
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
            if !state.slipStore.slip.selections.isEmpty {
                slipContent
            } else if let message = state.betPlacedMessage {
                placedState(message)
            } else {
                emptyState
            }
        }
        .animation(.smooth(duration: 0.35), value: state.slipStore.slip.selections.count)
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
                Button {
                    path.append(.deposit)
                } label: {
                    // Filling the row and giving it a shape is what makes the whole row
                    // tappable; a bare title button only responds on the glyphs themselves.
                    Text("Add funds")
                        .frame(maxWidth: .infinity, minHeight: DesignTokens.Layout.minTapTarget, alignment: .leading)
                        .contentShape(.rect)
                }
            }
        }
        .listStyle(.insetGrouped)
        // A bar rather than a plain inset: the list keeps scrolling under it and the glass
        // picks up the scroll edge effect, so the last row stays legible behind the button.
        .safeAreaBar(edge: .bottom) { placeBetBar }
        .scrollDismissesKeyboard(.interactively)
    }

    /// One leg is a single, two or more is an accumulator. The user never picks — the slip
    /// just says which one it currently is.
    private var betTypeTitle: String {
        state.slipStore.slip.mode == .accumulator ? "Accumulator" : "Single"
    }

    /// An `HStack` rather than `LabeledContent`: the two-line label pushes that layout into
    /// its stacked form, which drops the odds under the fighter instead of out to the edge.
    private func selectionRow(_ selection: SelectionRecord) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading) {
                Text(fighterName(selection.fighterId))
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
        PresetChipRow {
            ForEach([5, 10, 25, 50], id: \.self) { chip in
                PresetChipButton(title: "€\(chip)") { state.slipStore.setStake(String(format: "%.2f", Double(chip))) }
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
        // Whatever the bar is currently sitting on — tab bar or keyboard — it should not
        // look welded to it.
        .padding(.bottom, stakeFocused ? DesignTokens.Layout.actionBarGap : DesignTokens.Layout.tabBarActionGap)
        .animation(.snappy(duration: 0.25), value: stakeFocused)
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
