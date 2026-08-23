//
// BetSlipRootView.swift
// FightDeckBetslip
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import FightDeckCore
import SwiftUI

public struct BetSlipRootView: View {
    @Bindable var store: BetSlipStore
    let display: SlipDisplayContext
    let theme: BetslipTheme
    let onDeposit: @Sendable () -> Void
    let onBrowseEvents: @Sendable () -> Void
    let onHostSync: @Sendable (BetSlip, Decimal, String?) -> Void

    @FocusState private var stakeFocused: Bool

    public init(
        store: BetSlipStore,
        display: SlipDisplayContext,
        theme: BetslipTheme,
        onDeposit: @escaping @Sendable () -> Void,
        onBrowseEvents: @escaping @Sendable () -> Void,
        onHostSync: @escaping @Sendable (BetSlip, Decimal, String?) -> Void
    ) {
        self.store = store
        self.display = display
        self.theme = theme
        self.onDeposit = onDeposit
        self.onBrowseEvents = onBrowseEvents
        self.onHostSync = onHostSync
    }

    public var body: some View {
        Group {
            if store.slip.selections.isEmpty {
                emptyState
            } else {
                slipContent
            }
        }
        .background(theme.background)
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingLG) {
            Text("No selections yet")
                .foregroundStyle(theme.textSecondary)
            Button("Browse Events", action: onBrowseEvents)
                .font(Typography.semibold(theme.fontCallout))
                .foregroundStyle(theme.onAccent)
                .padding(Edge.Set.horizontal, theme.spacingXL)
                .padding(Edge.Set.vertical, theme.spacingMD)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMD))
        }
        .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
    }

    private var slipContent: some View {
        ScrollView {
            VStack(alignment: HorizontalAlignment.leading, spacing: theme.spacingLG) {
                Text(betTypeTitle)
                    .font(Typography.semibold(theme.fontCallout))
                    .foregroundStyle(theme.textPrimary)
                ForEach(store.slip.selections) { selection in
                    selectionRow(selection)
                }
                stakeField
                summaryBlock
                validationErrors
                depositSection
                actions
            }
            .padding(theme.spacingLG)
        }
        .toolbar {
            ToolbarItemGroup(placement: ToolbarItemPlacement.keyboard) {
                Spacer()
                Button("Done") { stakeFocused = false }
            }
        }
    }

    /// One leg is a single, two or more is an accumulator. The user never picks — the slip
    /// just says which one it currently is.
    private var betTypeTitle: String {
        store.slip.mode == BetMode.accumulator ? "Accumulator" : "Single"
    }

    private func selectionRow(_ selection: Selection) -> some View {
        HStack {
            VStack(alignment: HorizontalAlignment.leading) {
                Text(display.fighterName(id: selection.fighterID))
                    .font(Typography.body(theme.fontCallout))
                Text("vs \(display.opponentName(for: selection)) · \(display.eventName(for: selection))")
                    .font(Typography.body(theme.fontCaption))
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            Text(FightCoreDisplay.formatOdds(selection.odds))
                .foregroundStyle(theme.accent)
            Button {
                store.removeSelection(id: selection.id)
                onHostSync(store.slip, store.balance, nil)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(width: 44, height: 44)
        }
        .padding(theme.spacingLG)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusLG))
    }

    private var stakeField: some View {
        VStack(alignment: HorizontalAlignment.leading, spacing: theme.spacingSM) {
            Text("Amount")
                .font(Typography.semibold(theme.fontCallout))
                .foregroundStyle(theme.textPrimary)
            TextField("Stake", text: stakeBinding)
                .keyboardType(UIKeyboardType.decimalPad)
                .focused($stakeFocused)
                .padding(theme.spacingLG)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusLG))
            HStack {
                ForEach([5, 10, 25, 50], id: \.self) { chip in
                    Button("€\(chip)") {
                        store.slip.stake = Money.parse(String(chip))
                        onHostSync(store.slip, store.balance, nil)
                    }
                    .font(Typography.medium(theme.fontCaption))
                    .padding(Edge.Set.horizontal, theme.spacingMD)
                    .padding(Edge.Set.vertical, theme.spacingSM)
                    .background(theme.surfaceElevated)
                    .foregroundStyle(theme.accent)
                    .clipShape(Capsule())
                }
            }
        }
    }

    private var stakeBinding: Binding<String> {
        Binding(
            get: { Money.format(store.slip.stake) },
            set: { newValue in
                store.slip.stake = Money.parse(newValue)
                onHostSync(store.slip, store.balance, nil)
            }
        )
    }

    private var summaryBlock: some View {
        let state = store.slipState
        return VStack(alignment: HorizontalAlignment.leading, spacing: theme.spacingSM) {
            summaryRow("Total stake", Money.formatCurrency(state.totalStake))
            if let display = state.combinedOddsDisplay {
                summaryRow("Combined odds", Money.format(display))
            }
            summaryRow("Potential return", Money.formatCurrency(state.potentialReturn))
            summaryRow("Potential profit", Money.formatCurrency(state.potentialProfit))
        }
        .font(Typography.body(theme.fontBody))
        .padding(theme.spacingLG)
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusLG))
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value)
        }
    }

    private var validationErrors: some View {
        VStack(alignment: HorizontalAlignment.leading, spacing: theme.spacingXS) {
            ForEach(store.slipState.errors, id: \.self) { error in
                Text(error.rawValue.replacingOccurrences(of: "_", with: " "))
                    .foregroundStyle(theme.negative)
                    .font(Typography.body(theme.fontCaption))
            }
        }
    }

    private var depositSection: some View {
        VStack(alignment: HorizontalAlignment.leading, spacing: theme.spacingSM) {
            Text("Deposit")
                .font(Typography.semibold(theme.fontCallout))
                .foregroundStyle(theme.textPrimary)
            HStack {
                Text("Balance")
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Text(Money.formatCurrency(store.balance))
            }
            .font(Typography.body(theme.fontBody))
            Button("Add funds") { onDeposit() }
                .font(Typography.semibold(theme.fontCallout))
                .foregroundStyle(theme.onAccent)
                .frame(maxWidth: CGFloat.infinity, minHeight: 52)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMD))
        }
        .padding(theme.spacingLG)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusLG))
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: theme.spacingMD) {
            if let message = store.betPlacedMessage {
                Text(message)
                    .font(Typography.medium(theme.fontCallout))
                    .foregroundStyle(theme.positive)
            }
            Button("Place bet") {
                store.placeBet()
                onHostSync(store.slip, store.balance, store.betPlacedMessage)
            }
            .font(Typography.semibold(theme.fontCallout))
            .foregroundStyle(theme.onAccent)
            .frame(maxWidth: CGFloat.infinity, minHeight: 52)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMD))
            .disabled(!store.slipState.errors.isEmpty)
        }
    }
}
