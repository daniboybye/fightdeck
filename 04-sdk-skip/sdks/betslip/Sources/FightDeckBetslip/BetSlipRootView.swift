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
    static let betSlipAccessoryHeight: CGFloat = 44
}

public struct BetSlipRootView: View {
    @Bindable var store: BetSlipStore
    let display: SlipDisplayContext
    let theme: ThemeTokens
    let onDeposit: @Sendable () -> Void
    let onBrowseEvents: @Sendable () -> Void
    let onHostSync: @Sendable (BetSlip, Decimal, String?) -> Void

    @FocusState private var stakeFocused: Bool
    @State private var stakeText: String = ""

    public init(
        store: BetSlipStore,
        display: SlipDisplayContext,
        theme: ThemeTokens,
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
        .onAppear { stakeText = Money.format(store.slip.stake) }
        .onChange(of: store.slip.stake) { _, newValue in
            // Only adopt the model's formatting when the user is not mid-edit.
            if !stakeFocused {
                stakeText = Money.format(newValue)
            }
        }
        .onChange(of: stakeFocused) { _, focused in
            if !focused {
                stakeText = Money.format(store.slip.stake)
            }
        }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if !SKIP
        .transition(.scale(scale: 0.92).combined(with: .opacity))
        #endif
    }

    private var placedIcon: some View {
        #if !SKIP
        Image(systemName: "checkmark.seal.fill")
            .font(Typography.body(48.0))
            .foregroundStyle(theme.positive)
            .symbolEffect(.bounce, options: .nonRepeating)
        #else
        // Same hole the remove button falls into: SkipUI has no Material mapping for the seal
        // and renders a warning triangle labelled "missing icon". A checkmark in a circle is
        // mapped, and it is what the deposit confirmation already shows.
        Image(systemName: "checkmark.circle.fill")
            .font(Typography.body(48.0))
            .foregroundStyle(theme.positive)
        #endif
    }

    private var slipContent: some View {
        #if SKIP
        skipSlipScroll
        #else
        nativeSlipList
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
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingLG) {
                    skipGroupedSection(title: betTypeTitle) {
                        ForEach(store.slip.selections) { selection in
                            SkipGroupedRow(
                                theme: theme,
                                isLast: selection.id == store.slip.selections.last?.id
                            ) {
                                skipSelectionRow(selection)
                            }
                        }
                    }
                    skipGroupedSection(title: "Stake") {
                        SkipGroupedRow(theme: theme, isLast: false) {
                            skipStakeField
                        }
                        SkipGroupedRow(theme: theme, isLast: true, compact: true) {
                            stakeChipRow
                        }
                    }
                    skipGroupedSection(title: nil) {
                        ForEach(0 ..< skipSummaryRows.count, id: \.self) { index in
                            SkipGroupedRow(
                                theme: theme,
                                isLast: index == skipSummaryRows.count - 1
                            ) {
                                skipSummaryRow(skipSummaryRows[index].label, skipSummaryRows[index].value)
                            }
                        }
                    }
                    if !skipErrorMessages.isEmpty {
                        skipGroupedSection(title: nil) {
                            ForEach(0 ..< skipErrorMessages.count, id: \.self) { index in
                                SkipGroupedRow(
                                    theme: theme,
                                    isLast: index == skipErrorMessages.count - 1
                                ) {
                                    Text(skipErrorMessages[index])
                                        .foregroundStyle(theme.negative)
                                        .font(Typography.body(theme.fontCaption))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    skipGroupedSection(title: "Deposit") {
                        SkipGroupedRow(theme: theme, isLast: false) {
                            skipLabeledRow("Balance", Money.formatCurrency(store.balance))
                        }
                        SkipGroupedRow(theme: theme, isLast: true) {
                            skipAddFundsButton
                        }
                    }
                }
                .padding(theme.spacingLG)
                .padding(.bottom, Layout.primaryActionHeight + Layout.tabBarActionGap + theme.spacingLG)
            }
            skipPlaceBetBar
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { stakeFocused = false }
            }
        }
    }

    private var skipPlaceBetBar: some View {
        skipPlaceBetActions
            .padding(.horizontal, theme.spacingLG)
            .padding(.bottom, Layout.tabBarActionGap)
    }

    private var skipSummaryRows: [(label: String, value: String)] {
        FightCoreDisplay.slipSummary(state: store.slipState)
    }

    private var skipErrorMessages: [String] {
        store.slipState.errors.map { $0.rawValue.replacingOccurrences(of: "_", with: " ") }
    }

    private var skipPlaceBetActions: some View {
        Button {
            store.placeBet()
            onHostSync(store.slip, store.balance, store.betPlacedMessage)
        } label: {
            // Text, not a Label: SF Symbol names have no Material equivalent, and SkipUI
            // substitutes a warning triangle announced as "missing icon".
            Text("Place bet")
                .font(Typography.semibold(theme.fontCallout))
                .foregroundStyle(theme.onAccent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: Layout.primaryActionHeight)
        .background(theme.accent)
        .clipShape(Capsule())
        .disabled(!store.slipState.errors.isEmpty)
    }

    private func skipGroupedSection<Content: View>(
        title: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            if let title {
                Text(title)
                    .font(Typography.body(theme.fontCallout))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, theme.spacingLG)
            }
            VStack(spacing: 0) {
                content()
            }
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLG))
        }
    }

    private struct SkipGroupedRow<Content: View>: View {
        let theme: ThemeTokens
        let isLast: Bool
        var compact = false
        @ViewBuilder let content: () -> Content

        var body: some View {
            VStack(spacing: 0) {
                content()
                    .padding(.horizontal, theme.spacingLG)
                    .padding(.vertical, compact ? theme.spacingSM : theme.spacingMD)
                if !isLast {
                    Rectangle()
                        .fill(theme.textSecondary.opacity(0.25))
                        .frame(height: 1)
                        .padding(.leading, theme.spacingLG)
                }
            }
        }
    }

    private func skipSelectionRow(_ selection: Selection) -> some View {
        HStack(alignment: .top, spacing: theme.spacingMD) {
            VStack(alignment: .leading) {
                Text(display.fighterName(id: selection.fighterID))
                    .font(Typography.body(theme.fontCallout))
                    .foregroundStyle(theme.textPrimary)
                Text("vs \(display.opponentName(for: selection)) · \(display.eventName(for: selection))")
                    .font(Typography.body(theme.fontCaption))
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(FightCoreDisplay.formatOdds(selection.odds))
                .font(Typography.semibold(theme.fontCallout))
                .foregroundStyle(theme.accent)
            Button {
                store.removeSelection(id: selection.id)
                onHostSync(store.slip, store.balance, nil)
            } label: {
                #if SKIP
                // SkipUI has no Material mapping for this symbol and renders a warning triangle
                // labelled "missing icon", which is both wrong visually and wrong for TalkBack.
                Text(verbatim: "✕")
                    .font(Typography.semibold(theme.fontCallout))
                    .foregroundStyle(theme.textSecondary)
                    .accessibilityLabel("Remove selection")
                #else
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(theme.textSecondary)
                    .accessibilityLabel("Remove selection")
                #endif
            }
            .frame(width: Layout.minTapTarget, height: Layout.minTapTarget)
        }
    }

    private var skipStakeField: some View {
        HStack {
            Text("Amount")
                .font(Typography.body(theme.fontBody))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            TextField("Stake", text: stakeBinding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($stakeFocused)
                .foregroundStyle(theme.textPrimary)
        }
        .frame(minHeight: Layout.minTapTarget)
    }

    private func skipSummaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(theme.textSecondary)
        }
        .font(Typography.body(theme.fontBody))
    }

    private func skipLabeledRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(theme.textPrimary)
        }
        .font(Typography.body(theme.fontBody))
    }

    private var skipAddFundsButton: some View {
        Button(action: onDeposit) {
            Text("Add funds")
                .font(Typography.body(theme.fontBody))
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity, minHeight: Layout.minTapTarget, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
    #endif

    #if !SKIP
    private var nativeSlipList: some View {
        List {
            Section(betTypeTitle) {
                ForEach(store.slip.selections) { selection in
                    listSelectionRow(selection)
                }
                .onDelete { offsets in
                    offsets.map { store.slip.selections[$0].id }.forEach { id in
                        store.removeSelection(id: id)
                        onHostSync(store.slip, store.balance, nil)
                    }
                }
            }
            Section("Stake") {
                LabeledContent("Amount") {
                    TextField("Stake", text: stakeBinding)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($stakeFocused)
                }
                stakeChipRow
            }
            Section {
                ForEach(Array(FightCoreDisplay.slipSummary(state: store.slipState).enumerated()), id: \.offset) { _, row in
                    LabeledContent(row.label, value: row.value)
                }
            }
            if !store.slipState.errors.isEmpty {
                Section {
                    ForEach(store.slipState.errors, id: \.self) { error in
                        Label(error.rawValue.replacingOccurrences(of: "_", with: " "), systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(theme.negative)
                    }
                }
            }
            Section("Deposit") {
                LabeledContent("Balance") {
                    Text(Money.formatCurrency(store.balance))
                }
                Button(action: onDeposit) {
                    Text("Add funds")
                        .frame(maxWidth: .infinity, minHeight: Layout.minTapTarget, alignment: .leading)
                        .contentShape(.rect)
                }
            }
        }
        .listStyle(.insetGrouped)
        // safeAreaBar clears the Place bet button; the tab accessory sits below that bar and
        // still needs its own scroll margin or the Deposit rows scroll into its glass slot.
        .contentMargins(.bottom, Layout.betSlipAccessoryHeight, for: .scrollContent)
        .scrollDismissesKeyboard(.interactively)
    }

    private func listSelectionRow(_ selection: Selection) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.spacingMD) {
            VStack(alignment: .leading) {
                Text(display.fighterName(id: selection.fighterID))
                Text("vs \(display.opponentName(for: selection)) · \(display.eventName(for: selection))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(FightCoreDisplay.formatOdds(selection.odds))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(theme.accent)
        }
    }
    #endif

    /// One leg is a single, two or more is an accumulator. The user never picks — the slip
    /// just says which one it currently is.
    private var betTypeTitle: String {
        store.slip.mode == BetMode.accumulator ? "Accumulator" : "Single"
    }

    /// The field shows what the user typed, not a re-formatted view of the parsed amount.
    /// Compose renders exactly what the state says, so formatting on every read would round
    /// "0.007" back to "0.01" and swallow the keystroke. SwiftUI hides this behind its own
    /// editing buffer, which is why the same binding only misbehaves on Android.
    private var stakeBinding: Binding<String> {
        Binding(
            get: { stakeText },
            set: { newValue in
                // Compose emits one last empty change when the field leaves composition, which
                // is how switching tabs used to wipe the amount the user had just typed. Only a
                // focused field is being edited, so anything else is teardown noise.
                stakeText = newValue
                if newValue.isEmpty {
                    applyStake(Money.zero)
                } else if let amount = Money.parseOrNil(newValue) {
                    applyStake(amount)
                }
                // Anything else is text the user is midway through, or the stray separator
                // Compose sends as the field leaves composition. Treating it as zero is what
                // used to wipe the amount on a tab switch.
            }
        )
    }

    private func setStake(_ amount: Decimal) {
        stakeText = Money.format(amount)
        applyStake(amount)
    }

    /// The slip handed to the host is built with the new stake rather than read back from the
    /// store, because a read inside the text field's change callback can still see the value
    /// from the composition that produced the callback and push a stale amount.
    private func applyStake(_ amount: Decimal) {
        store.setStake(amount)
        var synced = store.slip
        synced.stake = amount
        onHostSync(synced, store.balance, nil)
    }

    private var stakeChipRow: some View {
        #if SKIP
        HStack(spacing: theme.spacingSM) {
            ForEach([5, 10, 25, 50], id: \.self) { chip in
                stakeChip("€\(chip)") {
                    setStake(Money.fromInt(chip))
                }
            }
        }
        #else
        PresetChipRow(theme: theme.chipTheme) {
            ForEach([5, 10, 25, 50], id: \.self) { chip in
                PresetChipButton(title: "€\(chip)", theme: theme.chipTheme) {
                    setStake(Money.fromInt(chip))
                }
            }
        }
        #endif
    }

    private func secondaryBrowseButton(action: @escaping @Sendable () -> Void) -> some View {
        #if SKIP
        Button(action: action) {
            Text("Browse Events")
                .font(Typography.semibold(theme.fontCallout))
                .foregroundStyle(theme.onAccent)
                .padding(.horizontal, Layout.secondaryActionPadding)
                .frame(maxHeight: .infinity)
        }
        .frame(height: Layout.secondaryActionHeight)
        .background(theme.accent)
        .clipShape(Capsule())
        #else
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
        #endif
    }

    @ViewBuilder
    private func stakeChip(_ title: String, action: @escaping () -> Void) -> some View {
        #if SKIP
        Button(action: action) {
            Text(title)
                .font(Typography.medium(theme.fontCaption))
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: Layout.secondaryActionHeight)
        .background(theme.surface)
        .overlay {
            Capsule()
                .stroke(theme.textSecondary.opacity(0.35), lineWidth: 1)
        }
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
        content
            .animation(.smooth(duration: 0.35), value: selectionCount)
            .animation(.smooth(duration: 0.35), value: betPlacedMessage)
            .sensoryFeedback(.success, trigger: betPlacedMessage) { _, new in new != nil }
    }
}

private struct SlipBottomBarModifier: ViewModifier {
    let theme: ThemeTokens
    let stakeFocused: Bool
    let isEnabled: Bool
    let onPlaceBet: () -> Void
    let onDismissKeyboard: () -> Void

    func body(content: Content) -> some View {
        content
            .safeAreaBar(edge: .bottom) { barContent }
            .scrollDismissesKeyboard(.interactively)
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
        // Host tab accessory now owns tab-bar clearance; tabBarActionGap would double up.
        .padding(.bottom, Layout.actionBarGap)
        .animation(.snappy(duration: 0.25), value: stakeFocused)
    }

    private var placeBetButton: some View {
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
    }

    private var keyboardDoneButton: some View {
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
    }
}
#endif
