//
// BetSlipRootView.swift
// FightDeckBetslip
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import SwiftUI

/// Only what this screen alone needs. The action-button numbers it shares with the deposit
/// screen live in the core's `Metrics`.
private enum Layout {
    static let minTapTarget: CGFloat = 44
    static let betSlipAccessoryHeight: CGFloat = 44
}

public struct BetSlipRootView: View {
    @Bindable var store: BetSlipStore
    let display: CatalogSlipDisplay
    let onDeposit: @Sendable () -> Void
    let onBrowseEvents: @Sendable () -> Void

    @Environment(\.fightDeckTheme) private var theme: ThemeTokens
    @FocusState private var stakeFocused: Bool
    @State private var stakeText: String = ""

    public init(
        store: BetSlipStore,
        display: CatalogSlipDisplay,
        onDeposit: @escaping @Sendable () -> Void,
        onBrowseEvents: @escaping @Sendable () -> Void
    ) {
        self.store = store
        self.display = display
        self.onDeposit = onDeposit
        self.onBrowseEvents = onBrowseEvents
    }

    public var body: some View {
        platformChrome(rootContent)
            .background(theme.background)
            .onAppear { stakeText = Money.formatCurrency(store.slip.stake) }
            .onChange(of: store.slip.stake) { _, newValue in
                // Only adopt the model's formatting when the user is not mid-edit.
                if !stakeFocused {
                    stakeText = Money.formatCurrency(newValue)
                }
            }
            .onChange(of: stakeFocused) { _, focused in
                // Out of focus the field shows currency, in focus it shows the bare number the
                // user types. `TextField(value:format:)` would do this on its own, but that
                // initialiser rests on Foundation's `FormatStyle`, which needs the ICU the
                // Android build deliberately leaves out — so the swap is explicit.
                stakeText = focused
                    ? Money.format(store.slip.stake)
                    : Money.formatCurrency(store.slip.stake)
            }
            .modifier(FightDeckScreen(theme: theme))
    }

    @ViewBuilder
    private var rootContent: some View {
        if !store.slip.selections.isEmpty {
            slipContent
        } else if let message = store.betPlacedMessage {
            placedState(message)
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingLG) {
            Text("No selections yet")
                .foregroundStyle(theme.textSecondary)
            browseButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Placing a bet empties the slip, so the confirmation has to live where the slip was.
    private func placedState(_ message: String) -> some View {
        placedCard(message)
            .modifier(ConfirmationTransition())
    }

    private func placedCard(_ message: String) -> some View {
        VStack(spacing: theme.spacingLG) {
            placedIcon
            Text("Bet placed")
                .font(Typography.bold(theme.fontCallout))
                .foregroundStyle(theme.textPrimary)
            Text(message)
                .font(Typography.body(theme.fontCallout))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
            browseButton
        }
        .padding(theme.spacingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

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
                    store.setStake(Money.zero)
                } else if let amount = Money.parseOrNil(newValue) {
                    store.setStake(amount)
                }
                // Anything else is text the user is midway through, or the stray separator
                // Compose sends as the field leaves composition. Treating it as zero is what
                // used to wipe the amount on a tab switch.
            }
        )
    }

    private func setStake(_ amount: Decimal) {
        stakeText = Money.format(amount)
        store.setStake(amount)
    }

    /// Swipe to delete is the iOS gesture for it; Android gets an explicit ✕ in the row
    /// instead. `.onDelete` is ✅ in SkipUI, but a hidden swipe is not how a Compose list
    /// removes a row.
    private var selectionRows: some View {
        ForEach(store.slip.selections) { selection in
            selectionRow(selection)
        }
        #if !SKIP
        .onDelete { offsets in
            for id in offsets.map({ store.slip.selections[$0].id }) {
                store.removeSelection(id: id)
            }
        }
        #endif
    }

    // MARK: - Shared list

    /// One `List` for both platforms, the same shape the fighter and deposit screens use, styled
    /// by the core's `InsetGroupedList`: inset-grouped cards on iOS, a Material list on Android.
    private var slipList: some View {
        List {
            selectionsSection
            stakeSection
            summarySection
            errorsSection
            depositSection
        }
    }

    /// The list with Place bet pinned under it. On iOS the host's tab accessory sits below the
    /// bar and needs its own scroll margin, or the Deposit rows scroll into its glass slot.
    private var slipContent: some View {
        slipList
            .modifier(InsetGroupedList(theme: theme))
            .modifier(PinnedActionBar(
                ActionBar(
                    "Place bet",
                    systemImage: "checkmark.seal",
                    isEnabled: store.slipState.errors.isEmpty,
                    showsDone: stakeFocused,
                    style: ActionBarStyle.floating,
                    theme: theme,
                    onPrimary: { store.placeBet() },
                    onDone: { stakeFocused = false }
                ),
                accessoryClearance: Layout.betSlipAccessoryHeight
            ))
    }

    private var selectionsSection: some View {
        Section {
            selectionRows
        } header: {
            sectionTitle(betTypeTitle)
        }
    }

    private var stakeSection: some View {
        Section {
            stakeAmountRow
            stakeChipRow
        } header: {
            sectionTitle("Stake")
        }
    }

    /// Fully shared: every row is the core's `LabeledRow`, reached through `labeledRow` so the
    /// transpiler composes it rather than dropping a bare initialiser.
    private var summarySection: some View {
        Section {
            ForEach(FightCoreDisplay.slipSummary(state: store.slipState)) { row in
                labeledRow(row.label, row.value, valueStyle: theme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var errorsSection: some View {
        if !store.slipState.errors.isEmpty {
            Section {
                ForEach(store.slipState.errors, id: \.self) { error in
                    errorRow(error.rawValue.replacingOccurrences(of: "_", with: " "))
                }
            }
        }
    }

    private var depositSection: some View {
        Section {
            labeledRow("Balance", Money.formatCurrency(store.balance), valueStyle: theme.textPrimary)
            addFundsButton
        } header: {
            sectionTitle("Deposit")
        }
    }

    // MARK: - The core's controls
    //
    // Each reached through a function, never as a bare initialiser in a `@ViewBuilder`:
    // `skipstone` emits `foo(...).Compose(context)` for a call that returns a view, but a struct
    // initialiser written straight into a builder becomes a constructor statement whose result
    // is dropped — the row is built and never composed, with no error anywhere. See
    // `GroupedList.swift`.

    private func labeledRow(_ label: String, _ value: String, valueStyle: Color) -> some View {
        LabeledRow(theme: theme, label: label, value: value, valueStyle: valueStyle)
    }

    private func sectionTitle(_ title: String) -> some View {
        SectionHeader(title, theme: theme)
    }

    private func errorRow(_ message: String) -> some View {
        ErrorRow(message, theme: theme)
    }

    private var browseButton: some View {
        SecondaryActionButton("Browse Events", theme: theme, action: onBrowseEvents)
    }

    private var addFundsButton: some View {
        RowButton("Add funds", action: onDeposit)
    }

    private var placedIcon: some View {
        ConfirmationIcon(size: 48.0, theme: theme)
    }

    private var stakeChipRow: some View {
        PresetChipRow(values: ["5", "10", "25", "50"], theme: theme.chipTheme) { value in
            setStake(Money.parse(value))
        }
    }
}

// MARK: - Skip (Android)

#if SKIP
extension BetSlipRootView {
    /// Compose animates its own state changes and has no haptic to arm.
    fileprivate func platformChrome(_ content: some View) -> some View {
        content
    }

    /// `LabeledContent` had no SkipUI mapping when this was written, so the row is an `HStack`
    /// here and the real thing on iOS.
    fileprivate var stakeAmountRow: some View {
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

    fileprivate func selectionRow(_ selection: Selection) -> some View {
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
            } label: {
                // SkipUI has no Material mapping for xmark.circle.fill and renders a warning
                // triangle labelled "missing icon", which is wrong for TalkBack.
                Text(verbatim: "✕")
                    .font(Typography.semibold(theme.fontCallout))
                    .foregroundStyle(theme.textSecondary)
                    .accessibilityLabel("Remove selection")
            }
            .frame(width: Layout.minTapTarget, height: Layout.minTapTarget)
        }
    }
}
#endif

// MARK: - Native (iOS)

#if !SKIP
extension BetSlipRootView {
    fileprivate func platformChrome(_ content: some View) -> some View {
        content
            .animation(.smooth(duration: 0.35), value: store.slip.selections.count)
            .animation(.smooth(duration: 0.35), value: store.betPlacedMessage)
            .sensoryFeedback(.success, trigger: store.betPlacedMessage) { _, new in new != nil }
    }

    fileprivate var stakeAmountRow: some View {
        LabeledContent("Amount") {
            TextField("Stake", text: stakeBinding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($stakeFocused)
        }
    }

    fileprivate func selectionRow(_ selection: Selection) -> some View {
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
}
#endif
