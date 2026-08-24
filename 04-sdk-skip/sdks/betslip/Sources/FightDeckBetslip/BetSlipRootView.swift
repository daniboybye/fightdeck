//
// BetSlipRootView.swift
// FightDeckBetslip
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import SwiftUI

private enum Layout {
    static let minTapTarget: CGFloat = 44
    static let primaryActionHeight: CGFloat = 44
    static let secondaryActionHeight: CGFloat = 44
    static let secondaryActionPadding: CGFloat = 24
    static let actionBarGap: CGFloat = 12
    static let tabBarActionGap: CGFloat = 20
}

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
            if !store.slip.selections.isEmpty {
                slipContent
            } else if let message = store.betPlacedMessage {
                placedState(message)
            } else {
                emptyState
            }
        }
        .background(theme.background)
        #if !SKIP
        .modifier(SlipPresentationModifier(
            selectionCount: store.slip.selections.count,
            betPlacedMessage: store.betPlacedMessage
        ))
        #endif
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingLG) {
            Text("No selections yet")
                .foregroundStyle(theme.textSecondary)
            secondaryBrowseButton(action: onBrowseEvents)
        }
        .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
    }

    /// Placing a bet empties the slip, so the confirmation has to live where the slip was.
    private func placedState(_ message: String) -> some View {
        VStack(spacing: theme.spacingLG) {
            placedIcon
            Text("Bet placed")
                .font(Typography.bold(theme.fontCallout))
                .foregroundStyle(theme.textPrimary)
            Text(message)
                .font(Typography.body(theme.fontCallout))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
            secondaryBrowseButton(action: onBrowseEvents)
        }
        .padding(theme.spacingXL)
        .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
        #if !SKIP
        .transition(.scale(scale: 0.92).combined(with: .opacity))
        #endif
    }

    @ViewBuilder
    private var placedIcon: some View {
        #if !SKIP
        if #available(iOS 18, *) {
            Image(systemName: "checkmark.seal.fill")
                .font(Typography.body(48))
                .foregroundStyle(theme.positive)
                .symbolEffect(.bounce, options: .nonRepeating)
        } else {
            Image(systemName: "checkmark.seal.fill")
                .font(Typography.body(48))
                .foregroundStyle(theme.positive)
        }
        #else
        Image(systemName: "checkmark.seal.fill")
            .font(Typography.body(48))
            .foregroundStyle(theme.positive)
        #endif
    }

    private var slipContent: some View {
        #if SKIP
        skipSlipScroll
        #else
        slipScroll
            .modifier(SlipBottomBarModifier(
                theme: theme,
                stakeFocused: stakeFocused,
                isEnabled: store.slipState.errors.isEmpty,
                onPlaceBet: {
                    store.placeBet()
                    onHostSync(store.slip, store.balance, store.betPlacedMessage)
                },
                onDismissKeyboard: { stakeFocused = false }
            ))
        #endif
    }

    #if SKIP
    private var skipSlipScroll: some View {
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
                skipPlaceBetActions
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

    private var skipPlaceBetActions: some View {
        Button {
            store.placeBet()
            onHostSync(store.slip, store.balance, store.betPlacedMessage)
        } label: {
            Label("Place bet", systemImage: "checkmark.seal")
                .font(Typography.semibold(theme.fontCallout))
                .foregroundStyle(theme.onAccent)
                .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
        }
        .frame(height: Layout.primaryActionHeight)
        .background(theme.accent)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMD))
        .disabled(!store.slipState.errors.isEmpty)
    }
    #endif

    private var slipScroll: some View {
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
            }
            .padding(theme.spacingLG)
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
            .frame(maxWidth: CGFloat.infinity, alignment: .leading)
            Text(FightCoreDisplay.formatOdds(selection.odds))
                .foregroundStyle(theme.accent)
            Button {
                store.removeSelection(id: selection.id)
                onHostSync(store.slip, store.balance, nil)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(width: Layout.minTapTarget, height: Layout.minTapTarget)
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
            stakeChipRow
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

    @ViewBuilder
    private var stakeChipRow: some View {
        #if SKIP
        HStack {
            ForEach([5, 10, 25, 50], id: \.self) { chip in
                stakeChip("€\(chip)") {
                    store.slip.stake = Money.parse(String(chip))
                    onHostSync(store.slip, store.balance, nil)
                }
            }
        }
        #else
        PresetChipRow(theme: theme) {
            ForEach([5, 10, 25, 50], id: \.self) { chip in
                PresetChipButton(title: "€\(chip)", theme: theme) {
                    store.slip.stake = Money.parse(String(chip))
                    onHostSync(store.slip, store.balance, nil)
                }
            }
        }
        #endif
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
            Button(action: onDeposit) {
                Text("Add funds")
                    .font(Typography.semibold(theme.fontCallout))
                    .foregroundStyle(theme.onAccent)
                    .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
            }
            .frame(height: Layout.minTapTarget)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMD))
        }
        .padding(theme.spacingLG)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusLG))
    }

    @ViewBuilder
    private func secondaryBrowseButton(action: @escaping @Sendable () -> Void) -> some View {
        #if SKIP
        Button(action: action) {
            Text("Browse Events")
                .font(Typography.semibold(theme.fontCallout))
                .foregroundStyle(theme.onAccent)
                .padding(.horizontal, Layout.secondaryActionPadding)
                .frame(maxHeight: CGFloat.infinity)
        }
        .frame(height: Layout.secondaryActionHeight)
        .background(theme.accent)
        .clipShape(Capsule())
        #else
        Group {
            if #available(iOS 26, *) {
                Button(action: action) {
                    Text("Browse Events")
                        .font(.headline)
                        .foregroundStyle(theme.onAccent)
                        .padding(.horizontal, Layout.secondaryActionPadding)
                        .frame(height: Layout.secondaryActionHeight)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(theme.accent).interactive(), in: .capsule)
            } else {
                Button(action: action) {
                    Text("Browse Events")
                        .font(Typography.semibold(theme.fontCallout))
                        .foregroundStyle(theme.onAccent)
                        .padding(.horizontal, Layout.secondaryActionPadding)
                        .frame(maxHeight: .infinity)
                        .contentShape(.rect)
                }
                .frame(height: Layout.secondaryActionHeight)
                .background(theme.accent)
                .clipShape(Capsule())
            }
        }
        #endif
    }

    @ViewBuilder
    private func stakeChip(_ title: String, action: @escaping () -> Void) -> some View {
        #if SKIP
        Button(action: action) {
            Text(title)
                .font(Typography.medium(theme.fontCaption))
                .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
        }
        .frame(height: Layout.secondaryActionHeight)
        .background(theme.surfaceElevated)
        .foregroundStyle(theme.accent)
        .clipShape(Capsule())
        #else
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(theme.accent)
        .frame(height: Layout.secondaryActionHeight)
        #endif
    }
}

#if !SKIP
private struct SlipPresentationModifier: ViewModifier {
    let selectionCount: Int
    let betPlacedMessage: String?

    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content
                .animation(.smooth(duration: 0.35), value: selectionCount)
                .animation(.smooth(duration: 0.35), value: betPlacedMessage)
                .sensoryFeedback(.success, trigger: betPlacedMessage) { _, new in new != nil }
        } else {
            content
        }
    }
}

private struct SlipBottomBarModifier: ViewModifier {
    let theme: BetslipTheme
    let stakeFocused: Bool
    let isEnabled: Bool
    let onPlaceBet: () -> Void
    let onDismissKeyboard: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .safeAreaBar(edge: .bottom) { barContent }
                .scrollDismissesKeyboard(.interactively)
        } else {
            legacyBottomBar(content)
        }
    }

    private func legacyBottomBar(_ content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                barContent
                    .padding(theme.spacingLG)
                    .background(.bar)
            }
            .toolbar {
                ToolbarItemGroup(placement: ToolbarItemPlacement.keyboard) {
                    Spacer()
                    Button("Done", action: onDismissKeyboard)
                }
            }
    }

    private var barContent: some View {
        HStack(spacing: theme.spacingSM) {
            placeBetButton
            if stakeFocused {
                keyboardDoneButton
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, theme.spacingLG)
        // Whatever the bar is currently sitting on — tab bar or keyboard — it should not look
        // welded to it, and the host's floating tab bar sits above the safe area it reports.
        .padding(.bottom, stakeFocused ? Layout.actionBarGap : Layout.tabBarActionGap)
        .animation(.snappy(duration: 0.25), value: stakeFocused)
    }

    @ViewBuilder
    private var placeBetButton: some View {
        if #available(iOS 26, *) {
            Button(action: onPlaceBet) {
                Label("Place bet", systemImage: "checkmark.seal")
                    .font(.headline)
                    .foregroundStyle(isEnabled ? theme.onAccent : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.primaryActionHeight)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .glassEffect(
                .regular
                    .tint(isEnabled ? theme.accent : nil)
                    .interactive(isEnabled),
                in: .capsule
            )
            .disabled(!isEnabled)
        } else {
            Button(action: onPlaceBet) {
                Label("Place bet", systemImage: "checkmark.seal")
                    .font(Typography.semibold(theme.fontCallout))
                    .foregroundStyle(theme.onAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(.rect)
            }
            .frame(height: Layout.primaryActionHeight)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMD))
            .disabled(!isEnabled)
        }
    }

    @ViewBuilder
    private var keyboardDoneButton: some View {
        if #available(iOS 26, *) {
            Button(action: onDismissKeyboard) {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, theme.spacingLG)
                    .frame(height: Layout.primaryActionHeight)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            Button(action: onDismissKeyboard) {
                Text("Done")
                    .font(Typography.semibold(theme.fontCallout))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, theme.spacingMD)
                    .frame(maxHeight: .infinity)
                    .contentShape(.rect)
            }
            .frame(height: Layout.primaryActionHeight)
            .background(theme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMD))
        }
    }
}

private struct PresetChipRow<Content: View>: View {
    let theme: BetslipTheme
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: theme.spacingSM) {
                HStack(spacing: theme.spacingSM) {
                    content()
                }
            }
        } else {
            HStack(spacing: theme.spacingSM) {
                content()
            }
        }
    }
}

private struct PresetChipButton: View {
    let title: String
    let theme: BetslipTheme
    let action: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            Button(action: action) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.secondaryActionHeight)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            Button(action: action) {
                Text(title)
                    .font(Typography.medium(theme.fontCaption))
                    .foregroundStyle(theme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(.rect)
            }
            .frame(height: Layout.secondaryActionHeight)
            .background(theme.surfaceElevated)
            .clipShape(Capsule())
        }
    }
}
#endif
