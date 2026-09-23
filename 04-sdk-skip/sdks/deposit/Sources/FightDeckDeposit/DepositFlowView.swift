//
// DepositFlowView.swift
// FightDeckDeposit
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import SwiftUI

/// Only what this screen alone needs. The action-button numbers it shares with the bet slip
/// live in the core's `Metrics`.
private enum Layout {
    static let radioDiameter: CGFloat = 20
    static let radioBorder: CGFloat = 2
    static let radioInset: CGFloat = 5
}

private enum DepositLimits {
    static let minimum = Money.parse("10")
    static let maximum = Money.parse("2000")
}

public struct DepositFlowView: View {
    public let params: DepositParams
    public let theme: ThemeTokens
    public let onResult: @Sendable (DepositResult) -> Void

    @State private var amountText = ""
    @State private var method = DepositMethod.card
    @State private var didSucceed = false
    @FocusState private var amountFocused: Bool

    public init(params: DepositParams, theme: ThemeTokens, onResult: @escaping @Sendable (DepositResult) -> Void) {
        self.params = params
        self.theme = theme
        self.onResult = onResult
    }

    private enum DepositMethod: String, CaseIterable, Identifiable {
        case card
        case bank
        case wallet

        var id: String { rawValue }

        var title: String {
            switch self {
            case DepositMethod.card: "Card"
            case DepositMethod.bank: "Bank transfer"
            case DepositMethod.wallet: "Wallet"
            }
        }

        /// Read only by the iOS `Picker`. SkipUI resolves `systemName` against a fixed table of
        /// Material icons, and none of these three are in it, so the Android rows draw their
        /// own mark instead.
        var symbol: String {
            switch self {
            case DepositMethod.card: "creditcard"
            case DepositMethod.bank: "building.columns"
            case DepositMethod.wallet: "wallet.bifold"
            }
        }

        var feeNote: String {
            switch self {
            case DepositMethod.card: "Instant · 0% fee"
            case DepositMethod.bank: "1–2 days · 0% fee"
            case DepositMethod.wallet: "Instant · 1% fee"
            }
        }

        var feeRate: Decimal {
            switch self {
            case DepositMethod.card, DepositMethod.bank: Money.zero
            case DepositMethod.wallet: Money.parse("0.01")
            }
        }
    }

    public var body: some View {
        platformChrome(
            Group {
                if didSucceed {
                    successContent
                } else {
                    formContent
                }
            }
        )
        // Nothing to name once it has happened: the confirmation says so in the middle of the
        // screen, where the eye already is, and a title would only repeat it in the corner.
        .navigationTitle(didSucceed ? "" : "Deposit")
        .toolbar {
            // The money has already moved by the time the confirmation shows, so that screen
            // leaves through Done only: closing it would offer to spend the deposit twice.
            if !didSucceed {
                ToolbarItem(placement: ToolbarItemPlacement.topBarLeading) {
                    Button("Close", systemImage: "xmark") { onResult(DepositResult.cancelled) }
                }
            }
        }
    }

    // One screen rather than an amount/method/confirm wizard: the whole flow is four fields
    // and stepping through them only hides the total from the person approving it.
    //
    // One `Form` for both platforms. `Form`, `Section` and `Picker` are all supported by SkipUI,
    // so the grouped structure is shared and each platform's own styling draws it — inset-grouped
    // on iOS, a Material list on Android. Only the rows that have no SkipUI mapping differ.
    private var depositForm: some View {
        Form {
            amountSection
            methodSection
            summarySection
        }
    }

    private var amountSection: some View {
        Section {
            TextField("€10 – €2,000", text: $amountText)
                .keyboardType(.decimalPad)
                .font(amountFont)
                .focused($amountFocused)
            if let message = amountValidationMessage {
                Text(message)
                    .foregroundStyle(theme.negative)
                    .font(Typography.body(theme.fontCaption))
            }
            amountChipRow
        } header: {
            sectionTitle("Amount")
        }
    }

    private var methodSection: some View {
        Section {
            methodPicker
        } header: {
            sectionTitle("Method")
        }
    }

    private var summarySection: some View {
        Section {
            summaryRow("Amount", Money.formatCurrency(parsedAmount))
            summaryRow("Method", method.title)
            summaryRow("Fee", Money.formatCurrency(feeAmount))
            summaryRow("Total", Money.formatCurrency(parsedAmount + feeAmount))
            summaryRow("New balance", Money.formatCurrency(params.currentBalance + parsedAmount))
        } header: {
            sectionTitle("Summary")
        }
    }

    private var successContent: some View {
        successChrome(
            VStack(spacing: theme.spacingLG) {
                successIcon
                Text("Deposit successful")
                    .font(Typography.bold(theme.fontTitle))
                Text("New balance: \(Money.formatCurrency(params.currentBalance + parsedAmount))")
                    .foregroundStyle(theme.textSecondary)
                secondaryDoneButton
            }
            .padding(theme.spacingXL)
        )
    }

    /// A section header, through a function — never `Text(…)` carrying a modifier of *ours* at
    /// the call site. A `View` extension of our own transpiles to a Kotlin extension function
    /// that `skipstone` does not recognise as producing a view: it emits the call with no
    /// `.Compose(context)` after it and the header silently renders nothing. That is attempt (2)
    /// in `GroupedList.swift`, reached by a different road. A plain function call is composed.
    ///
    /// The font is the whole of the Android fix — see `Typography.sectionHeader`. iOS gets a
    /// bare `Text` and therefore exactly the header SwiftUI drew before.
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
        #if SKIP
            .font(Typography.sectionHeader(theme))
        #endif
    }

    /// Identical on both platforms, so not behind an `#if`. It used to be, from when a shared
    /// view of ours was thought not to render on Android.
    private func summaryRow(_ label: String, _ value: String) -> some View {
        LabeledRow(theme: theme, label: label, value: value, valueStyle: theme.textPrimary)
    }

    /// One icon, one size. Only the bounce is iOS's — SwiftUI's symbol effects have no SkipUI
    /// mapping, and Compose animates its own state changes anyway.
    private var successIcon: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(Typography.body(64.0))
            .foregroundStyle(theme.positive)
        #if !SKIP
            .symbolEffect(.bounce, options: .nonRepeating)
        #endif
    }

    /// The confirmation replaces the content it sits on, so iOS scales it in. Compose animates
    /// its own state changes, so Android needs nothing.
    private func successChrome(_ content: some View) -> some View {
        content
        #if !SKIP
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        #endif
    }

    private var parsedAmount: Decimal {
        Money.parse(amountText.isEmpty ? "0" : amountText)
    }

    private var feeAmount: Decimal {
        Money.money(parsedAmount * method.feeRate)
    }

    private var amountValidationMessage: String? {
        let amount = parsedAmount
        if amountText.isEmpty { return nil }
        if amount < DepositLimits.minimum { return "Minimum deposit is €10" }
        if amount > DepositLimits.maximum { return "Maximum deposit is €2,000" }
        return nil
    }

    private var canConfirm: Bool {
        amountValidationMessage == nil && !amountText.isEmpty
    }

}

// MARK: - Skip (Android)

#if SKIP
extension DepositFlowView {
    fileprivate var amountFont: Font {
        Typography.bold(theme.fontDisplay)
    }

    /// `.pickerStyle(.inline)` is unsupported by SkipUI, so the method list is drawn as rows.
    /// They sit inside the shared `Section`, so the grouping still comes from SkipUI.
    fileprivate var methodPicker: some View {
        ForEach(DepositMethod.allCases) { item in
            Button {
                method = item
            } label: {
                methodRow(item)
            }
        }
    }

    /// No background or corner radius of its own: the row is a child of the shared `Section`, so
    /// the card behind it is SkipUI's. Painting one here as well stacked two surfaces.
    private func methodRow(_ item: DepositMethod) -> some View {
        HStack {
            methodMark(isSelected: method == item)
            VStack(alignment: .leading) {
                Text(item.title)
                    .foregroundStyle(theme.textPrimary)
                Text(item.feeNote)
                    .font(Typography.body(theme.fontCaption))
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
    }

    /// Drawn rather than named. SkipUI resolves `systemName` against a fixed table of Material
    /// icons and falls back to a warning triangle for anything absent from it; "circle" and
    /// "largecircle.fill.circle" are both absent, so on Android every method row wore the same
    /// missing-icon triangle and the selected one was indistinguishable. Two shapes transpile,
    /// and they render the same on iOS.
    private func methodMark(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isSelected ? theme.accent : theme.textSecondary,
                    lineWidth: Layout.radioBorder
                )
            if isSelected {
                Circle()
                    .fill(theme.accent)
                    .padding(Layout.radioInset)
            }
        }
        .frame(width: Layout.radioDiameter, height: Layout.radioDiameter)
    }

    /// Compose supplies the screen's own chrome. What it does not supply is the host's palette:
    /// SkipUI wraps every screen in a `MaterialTheme` of its own, so the scheme is handed in
    /// here or the Form comes back in Material You's wallpaper colours. See
    /// `fightDeckColorScheme`.
    fileprivate func platformChrome(_ content: some View) -> some View {
        content
            .material3ColorScheme { _, _ in fightDeckColorScheme(theme) }
    }

    // The confirm button rides above the scroll rather than at the end of it, the same shape the
    // slip screen uses: as the last row of a scroll it ends up behind the keyboard the amount
    // field raises, and SkipUI's scroll view will not extend its range far enough to reach it.
    fileprivate var formContent: some View {
        ZStack(alignment: .bottom) {
            // Without this the form paints its own container — `surfaceColorAtElevation(3dp)` —
            // over the root's background, on a slightly different shade from the rest of the app.
            depositForm
                .scrollContentBackground(.hidden)
                // The closest a SkipUI form gets to Material cards: `.listStyle(.insetGrouped)`
                // is unavailable and the section radius is a constant inside SkipUI, so the
                // slabs can only be moved off the screen edges from out here.
                .padding(.horizontal, theme.spacingLG)
            actionBar
        }
    }

    /// Done sits beside Confirm rather than on a keyboard toolbar: `ToolbarItemGroup` is
    /// supported, but its `.keyboard` placement draws nothing on Android, so the button would
    /// simply never appear. This is the shape the native screen uses anyway.
    ///
    /// On a fill: this screen's native counterpart puts the row in a `Surface(surfaceContainer)`
    /// so the form scrolls *under* a solid strip. The slip screen deliberately does not — three
    /// stacked surface tones there stop the selections pill reading as part of the same bar —
    /// which is why only this one has a background. Padding matches the native row: a smaller
    /// gap above the button than below it.
    private var actionBar: some View {
        HStack(spacing: theme.spacingSM) {
            confirmButton
            if amountFocused {
                doneButton
            }
        }
        .padding(.horizontal, theme.spacingLG)
        .padding(.top, theme.spacingSM)
        .padding(.bottom, Metrics.actionBarGap)
        .frame(maxWidth: .infinity)
        .background(theme.surface)
    }

    /// The one place this SDK drops to Compose. Setting `@FocusState` to false does clear
    /// SkipUI's focus — the button hides itself on the next pass — but it does not dismiss the
    /// Android IME. Only Compose's own focus manager does that, and reaching it needs a
    /// composable scope, which `ComposeView` is the documented way to open under Skip Lite.
    ///
    /// `FilledTonalButton`, not `TextButton`: a text button paints no container, so beside the
    /// filled Confirm button it read as loose text over the form. This is also the component
    /// `00-native` uses for the same button, and it takes its colours from
    /// `secondaryContainer`/`onSecondaryContainer` — which now resolve to the FightDeck palette
    /// because `platformChrome` hands SkipUI the host's scheme.
    private var doneButton: some View {
        ComposeView { _ in
            let focusManager = androidx.compose.ui.platform.LocalFocusManager.current
            androidx.compose.material3.FilledTonalButton(
                onClick: {
                    focusManager.clearFocus()
                    amountFocused = false
                },
                shape: androidx.compose.foundation.shape.RoundedCornerShape(percent: 50)
            ) {
                androidx.compose.material3.Text("Done")
            }
        }
        .frame(height: Metrics.secondaryActionHeight)
    }

    /// `.disabled()` stops the taps but changes nothing about how the button looks: the fill is
    /// ours, painted by `.background`, and SkipUI has no reason to touch a colour we chose. So
    /// a button with nothing typed in it sat there at full strength, reading as ready. Material
    /// dims both halves to 0.38, which is what `00-native`'s `PrimaryActionButton` does too.
    ///
    /// A capsule, not a rounded rectangle, for the same reason: the native button is
    /// `RoundedCornerShape(percent = 50)`, and so is the slip's Place bet beside it.
    private var confirmButton: some View {
        Button {
            didSucceed = true
        } label: {
            Text("Confirm deposit")
                .font(Typography.semibold(theme.fontCallout))
                .foregroundStyle(canConfirm ? theme.onAccent : theme.onAccent.opacity(Metrics.disabledOpacity))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: Metrics.primaryActionHeight)
        .background(canConfirm ? theme.accent : theme.accent.opacity(Metrics.disabledOpacity))
        .clipShape(Capsule())
        .disabled(!canConfirm)
    }


    /// Through a function, never as a bare `PresetChipButton(...)` in the builder: `skipstone`
    /// emits a constructor written straight into a `@ViewBuilder` as a statement and drops the
    /// result, so the chips came out invisible with no error anywhere. See `GroupedList.swift`.
    private func chipButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        PresetChipButton(title: title, theme: theme.chipTheme, action: action)
    }
    /// No glass container on Android — the chips themselves are the shared `PresetChipButton`.
    fileprivate var amountChipRow: some View {
        HStack(spacing: theme.spacingSM) {
            ForEach(["10", "25", "50", "100"], id: \.self) { chip in
                chipButton("€\(chip)") { amountText = chip }
            }
        }
    }

    fileprivate var secondaryDoneButton: some View {
        Button("Done") { onResult(DepositResult.completed(amount: parsedAmount)) }
            .font(Typography.semibold(theme.fontCallout))
            .foregroundStyle(theme.onAccent)
            .padding(.horizontal, Metrics.secondaryActionPadding)
            .frame(height: Metrics.secondaryActionHeight)
            .background(theme.accent)
            .clipShape(Capsule())
    }
}
#endif

// MARK: - Native (iOS)

#if !SKIP
extension DepositFlowView {
    fileprivate var amountFont: Font {
        .largeTitle.bold()
    }

    fileprivate var methodPicker: some View {
        Picker("Method", selection: $method) {
            ForEach(DepositMethod.allCases) { item in
                Label {
                    VStack(alignment: .leading) {
                        Text(item.title)
                        Text(item.feeNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: item.symbol)
                }
                .tag(item)
            }
        }
        .pickerStyle(.inline)
        .labelsHidden()
    }

    /// The haptic rides the root rather than the confirmation it belongs to: `sensoryFeedback`
    /// only fires on a change, and a modifier mounted together with the confirmation has
    /// already missed the one that put it on screen.
    fileprivate func platformChrome(_ content: some View) -> some View {
        content
            .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.inline)
            .animation(.smooth(duration: 0.35), value: didSucceed)
            .sensoryFeedback(.success, trigger: didSucceed)
    }

    fileprivate var formContent: some View {
        depositForm
            .scrollDismissesKeyboard(.interactively)
            .modifier(DepositBottomBarModifier(
                theme: theme,
                amountFocused: amountFocused,
                isEnabled: canConfirm,
                onConfirm: { didSucceed = true },
                onDismissKeyboard: { amountFocused = false }
            ))
    }

    fileprivate var amountChipRow: some View {
        PresetChipRow(theme: theme.chipTheme) {
            ForEach(["10", "25", "50", "100"], id: \.self) { chip in
                PresetChipButton(title: "€\(chip)", theme: theme.chipTheme) { amountText = chip }
            }
        }
    }

    fileprivate var secondaryDoneButton: some View {
        Button {
            onResult(DepositResult.completed(amount: parsedAmount))
        } label: {
            Text("Done")
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

private struct DepositBottomBarModifier: ViewModifier {
    let theme: ThemeTokens
    let amountFocused: Bool
    let isEnabled: Bool
    let onConfirm: () -> Void
    let onDismissKeyboard: () -> Void

    func body(content: Content) -> some View {
        content
            .safeAreaBar(edge: .bottom) { barContent }
            .scrollDismissesKeyboard(.interactively)
    }

    private var barContent: some View {
        HStack(spacing: theme.spacingSM) {
            primaryConfirmButton
            if amountFocused {
                keyboardDoneButton
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, theme.spacingLG)
        .padding(.bottom, Metrics.actionBarGap)
        .animation(.snappy(duration: 0.25), value: amountFocused)
    }

    private var primaryConfirmButton: some View {
        Button(action: onConfirm) {
            Text("Confirm deposit")
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
