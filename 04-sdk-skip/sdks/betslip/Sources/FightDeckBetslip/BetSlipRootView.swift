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
    static let tabBarActionGap: CGFloat = 20
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
            secondaryBrowseButton(action: onBrowseEvents)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Placing a bet empties the slip, so the confirmation has to live where the slip was.
    private func placedState(_ message: String) -> some View {
        placedChrome(placedCard(message))
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
            secondaryBrowseButton(action: onBrowseEvents)
        }
        .padding(theme.spacingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The confirmation replaces the content it sits on, so iOS scales it in. Compose animates
    /// its own state changes, so Android needs nothing.
    private func placedChrome(_ content: some View) -> some View {
        content
        #if !SKIP
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        #endif
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

    /// One icon, one size. `checkmark.seal.fill` has no Material mapping, so Android would draw
    /// a warning triangle announced as "missing icon" — the circle is mapped on both. Only the
    /// bounce is iOS's: symbol effects have no SkipUI mapping.
    private var placedIcon: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(Typography.body(48.0))
            .foregroundStyle(theme.positive)
        #if !SKIP
            .symbolEffect(.bounce, options: .nonRepeating)
        #endif
    }

    /// Shared but for the tap shape, which SkipUI has no mapping for. The row fills the width
    /// so the whole line is the target on both.
    private var addFundsButton: some View {
        Button(action: onDeposit) {
            Text("Add funds")
                .frame(maxWidth: .infinity, minHeight: Layout.minTapTarget, alignment: .leading)
            #if !SKIP
                .contentShape(.rect)
            #endif
        }
        #if SKIP
        // Without this the row takes Material's filled-button look instead of a list row.
        .buttonStyle(.plain)
        #endif
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

    /// One `List` for both platforms, the same shape the fighter and deposit screens use.
    /// `List` and `Section` are 🟢 in SkipUI's support table and `.onDelete` is ✅, so the
    /// grouped structure itself is shared and each platform's own list styling draws it —
    /// inset-grouped cards on iOS, a Material list on Android. Only the rows that have no
    /// SkipUI mapping are written twice.
    ///
    /// This screen used to draw its cards by hand on Android — `VStack`s with a `surface`
    /// background, a hand-rolled divider and a hand-placed section title. That was the last
    /// hand-drawn screen in the SDK, and the reason it could not use the shared `LabeledRow`.
    private var slipList: some View {
        List {
            selectionsSection
            stakeSection
            summarySection
            errorsSection
            depositSection
            listFooter
        }
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

    /// Through a function, never as a bare `LabeledRow(...)` in the builder. `skipstone` emits
    /// `foo(...).Compose(context)` for a call that returns a view, but a struct initialiser
    /// written straight into a `@ViewBuilder` transpiles to a bare constructor statement whose
    /// result is dropped — the row is built and never composed, and the section comes out empty
    /// with no error anywhere. The fighter and deposit screens only ever worked because they
    /// happened to route through `detailRow`/`summaryRow`.
    private func labeledRow(_ label: String, _ value: String, valueStyle: Color) -> some View {
        LabeledRow(theme: theme, label: label, value: value, valueStyle: valueStyle)
    }

    /// A section header, and the same rule again: through a function, never `Text(…)` carrying
    /// a modifier of *ours* at the call site. A `View` extension of our own transpiles to a
    /// Kotlin extension function that `skipstone` does not recognise as producing a view, so it
    /// emits the call with no `.Compose(context)` after it and the header silently renders
    /// nothing — attempt (2) in `GroupedList.swift`, reached by a different road.
    ///
    /// The font is the whole of the Android fix — see `Typography.sectionHeader`. iOS gets a
    /// bare `Text` and therefore exactly the header SwiftUI drew before.
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
        #if SKIP
            .font(Typography.sectionHeader(theme))
        #endif
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
}

// MARK: - Skip (Android)

#if SKIP
extension BetSlipRootView {
    /// Compose animates its own state changes and has no haptic to arm. What it does need is the
    /// host's palette: SkipUI wraps every screen in a `MaterialTheme` of its own, built from
    /// Material You's dynamic colours, so the `List` below would otherwise be drawn in the
    /// device wallpaper's scheme. See `fightDeckColorScheme`.
    fileprivate func platformChrome(_ content: some View) -> some View {
        content
            .material3ColorScheme { _, _ in fightDeckColorScheme(theme) }
    }

    fileprivate var slipContent: some View {
        ZStack(alignment: .bottom) {
            // Without this the list paints its own container — `surfaceColorAtElevation(3dp)` —
            // over the root's background, which is why the slip sat on a slightly different
            // shade from the rest of the app.
            slipList
                .scrollContentBackground(.hidden)
                // The closest a SkipUI list gets to Material cards: `.listStyle(.insetGrouped)`
                // is unavailable and the section radius is a constant inside SkipUI, so the
                // slabs can only be moved off the screen edges from out here.
                .padding(.horizontal, theme.spacingLG)
            placeBetBar
        }
    }

    /// `.contentMargins` — the modifier iOS uses to keep the last row clear of the pinned bar —
    /// has no SkipUI mapping, and a `VStack` with the list flexible and the bar fixed came out
    /// with the list filling the whole column and the bar drawn over its last rows. An empty
    /// trailing row is the shape that survives: it scrolls like content, because it is content.
    fileprivate var listFooter: some View {
        Color.clear
            .frame(height: Metrics.primaryActionHeight + Layout.tabBarActionGap)
            // Otherwise the spacer is drawn as an empty card, because a list row gets a row
            // background whether or not it has anything in it.
            .listRowBackground(Color.clear)
    }

    /// `LabeledContent` has no SkipUI mapping, so the row is an `HStack` here and the real thing
    /// on iOS. Everything around it — the `Section`, the divider, the card — now comes from
    /// SkipUI's `List`.
    private var stakeAmountRow: some View {
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

    /// Text, not a `Label`: SkipUI resolves `systemName` against a fixed table of Material icons
    /// and draws a warning triangle announced as "missing icon" for anything absent from it,
    /// which `exclamationmark.triangle.fill` is.
    private func errorRow(_ message: String) -> some View {
        Text(message)
            .foregroundStyle(theme.negative)
            .font(Typography.body(theme.fontCallout))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Done sits beside Place bet rather than on a keyboard toolbar: `ToolbarItemGroup` is
    /// supported by SkipUI, but its `.keyboard` placement draws nothing on Android, so the
    /// button simply never appeared. This is the shape the native screen uses anyway.
    private var placeBetBar: some View {
        HStack(spacing: theme.spacingSM) {
            placeBetButton
            if stakeFocused {
                doneButton
            }
        }
        .padding(.horizontal, theme.spacingLG)
        .padding(.bottom, Layout.tabBarActionGap)
    }

    /// `.disabled()` stops the taps but changes nothing about how the button looks: the fill is
    /// ours, painted by `.background`, and SkipUI has no reason to touch a colour we chose. A
    /// slip that cannot be placed therefore showed a button at full strength. Material dims
    /// both halves to 0.38, which is what `00-native`'s `PrimaryActionButton` does too.
    private var placeBetButton: some View {
        let canPlace = store.slipState.errors.isEmpty
        return Button(action: { store.placeBet() }) {
            // Text, not a Label: SF Symbol names have no Material equivalent, and SkipUI
            // substitutes a warning triangle announced as "missing icon".
            Text("Place bet")
                .font(Typography.semibold(theme.fontCallout))
                .foregroundStyle(canPlace ? theme.onAccent : theme.onAccent.opacity(Metrics.disabledOpacity))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: Metrics.primaryActionHeight)
        .background(canPlace ? theme.accent : theme.accent.opacity(Metrics.disabledOpacity))
        .clipShape(Capsule())
        .disabled(!canPlace)
    }

    /// The one place this SDK drops to Compose. Setting `@FocusState` to false does clear
    /// SkipUI's focus — the button hides itself on the next pass — but it does not dismiss the
    /// Android IME. Only Compose's own focus manager does that, and reaching it needs a
    /// composable scope, which `ComposeView` is the documented way to open under Skip Lite.
    ///
    /// `FilledTonalButton`, not `TextButton`: a text button paints no container, so beside the
    /// filled Place bet button it read as floating loose text over the list. This is also the
    /// component `00-native` uses for the same button, and it takes its colours from
    /// `secondaryContainer`/`onSecondaryContainer` — which now resolve to the FightDeck palette
    /// because `platformChrome` hands SkipUI the host's scheme.
    private var doneButton: some View {
        ComposeView { _ in
            let focusManager = androidx.compose.ui.platform.LocalFocusManager.current
            androidx.compose.material3.FilledTonalButton(
                onClick: {
                    focusManager.clearFocus()
                    stakeFocused = false
                },
                shape: androidx.compose.foundation.shape.RoundedCornerShape(percent: 50)
            ) {
                androidx.compose.material3.Text("Done")
            }
        }
        .frame(height: Metrics.secondaryActionHeight)
    }

    private func selectionRow(_ selection: Selection) -> some View {
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


    /// Through a function, never as a bare `PresetChipButton(...)` in the builder: `skipstone`
    /// emits a constructor written straight into a `@ViewBuilder` as a statement and drops the
    /// result, so the chips came out invisible with no error anywhere. See `GroupedList.swift`.
    private func chipButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        PresetChipButton(title: title, theme: theme.chipTheme, action: action)
    }
    /// No glass container on Android — the chips themselves are the shared `PresetChipButton`.
    fileprivate var stakeChipRow: some View {
        HStack(spacing: theme.spacingSM) {
            ForEach([5, 10, 25, 50], id: \.self) { chip in
                chipButton("€\(chip)") { setStake(Money.fromInt(chip)) }
            }
        }
    }

    fileprivate func secondaryBrowseButton(action: @escaping @Sendable () -> Void) -> some View {
        Button(action: action) {
            Text("Browse Events")
                .font(Typography.semibold(theme.fontCallout))
                .foregroundStyle(theme.onAccent)
                .padding(.horizontal, Metrics.secondaryActionPadding)
                .frame(maxHeight: .infinity)
        }
        .frame(height: Metrics.secondaryActionHeight)
        .background(theme.accent)
        .clipShape(Capsule())
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

    fileprivate var slipContent: some View {
        slipList
            .listStyle(.insetGrouped)
            // safeAreaBar clears the Place bet button; the tab accessory sits below that bar and
            // still needs its own scroll margin or the Deposit rows scroll into its glass slot.
            .contentMargins(.bottom, Layout.betSlipAccessoryHeight, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            .modifier(SlipBottomBarModifier(
                theme: theme,
                stakeFocused: stakeFocused,
                isEnabled: store.slipState.errors.isEmpty,
                onPlaceBet: { store.placeBet() },
                onDismissKeyboard: { stakeFocused = false }
            ))
    }

    private var stakeAmountRow: some View {
        LabeledContent("Amount") {
            TextField("Stake", text: stakeBinding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($stakeFocused)
        }
    }

    private func errorRow(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(theme.negative)
    }

    /// iOS reserves the bar's space with `.contentMargins`, so nothing is needed at the end of
    /// the list.
    fileprivate var listFooter: some View {
        EmptyView()
    }

    private func selectionRow(_ selection: Selection) -> some View {
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

    fileprivate var stakeChipRow: some View {
        PresetChipRow(theme: theme.chipTheme) {
            ForEach([5, 10, 25, 50], id: \.self) { chip in
                PresetChipButton(title: "€\(chip)", theme: theme.chipTheme) {
                    setStake(Money.fromInt(chip))
                }
            }
        }
    }

    fileprivate func secondaryBrowseButton(action: @escaping @Sendable () -> Void) -> some View {
        Button(action: action) {
            Text("Browse Events")
                .font(.headline)
                .foregroundStyle(theme.onAccent)
                .padding(.horizontal, Metrics.secondaryActionPadding)
                .frame(height: Metrics.secondaryActionHeight)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(theme.accent).interactive(), in: .capsule)
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
        .padding(.bottom, Metrics.actionBarGap)
        .animation(.snappy(duration: 0.25), value: stakeFocused)
    }

    private var placeBetButton: some View {
        Button(action: onPlaceBet) {
            Label("Place bet", systemImage: "checkmark.seal")
                .font(.headline)
                .foregroundStyle(isEnabled ? theme.onAccent : Color.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: Metrics.primaryActionHeight)
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
                .frame(height: Metrics.primaryActionHeight)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}
#endif
