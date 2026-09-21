//
// DepositFlowView.swift
// FightDeckDeposit
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import SwiftUI

private enum Layout {
    static let primaryActionHeight: CGFloat = 44
    static let secondaryActionHeight: CGFloat = 44
    static let secondaryActionPadding: CGFloat = 24
    static let actionBarGap: CGFloat = 12
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
        Section("Amount") {
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
        }
    }

    private var methodSection: some View {
        Section("Method") {
            methodPicker
        }
    }

    private var summarySection: some View {
        Section("Summary") {
            summaryRow("Amount", Money.formatCurrency(parsedAmount))
            summaryRow("Method", method.title)
            summaryRow("Fee", Money.formatCurrency(feeAmount))
            summaryRow("Total", Money.formatCurrency(parsedAmount + feeAmount))
            summaryRow("New balance", Money.formatCurrency(params.currentBalance + parsedAmount))
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

    fileprivate func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(theme.textPrimary)
        }
    }

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
        .padding(theme.spacingLG)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusLG))
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

    /// Compose supplies the screen's own chrome; nothing to add here.
    fileprivate func platformChrome(_ content: some View) -> some View {
        content
    }

    fileprivate func successChrome(_ content: some View) -> some View {
        content
    }

    // The confirm button rides above the scroll rather than at the end of it, the same shape the
    // slip screen uses: as the last row of a scroll it ends up behind the keyboard the amount
    // field raises, and SkipUI's scroll view will not extend its range far enough to reach it.
    fileprivate var formContent: some View {
        ZStack(alignment: .bottom) {
            depositForm
            actionBar
        }
    }

    /// Done sits beside Confirm rather than on a keyboard toolbar: `ToolbarItemGroup` is
    /// supported, but its `.keyboard` placement draws nothing on Android, so the button would
    /// simply never appear. This is the shape the native screen uses anyway.
    private var actionBar: some View {
        HStack(spacing: theme.spacingSM) {
            confirmButton
            if amountFocused {
                doneButton
            }
        }
        .padding(.horizontal, theme.spacingLG)
        .padding(.bottom, theme.spacingLG)
    }

    /// The one place this SDK drops to Compose. Setting `@FocusState` to false does clear
    /// SkipUI's focus — the button hides itself on the next pass — but it does not dismiss the
    /// Android IME. Only Compose's own focus manager does that, and reaching it needs a
    /// composable scope, which `ComposeView` is the documented way to open under Skip Lite.
    private var doneButton: some View {
        ComposeView { _ in
            let focusManager = androidx.compose.ui.platform.LocalFocusManager.current
            androidx.compose.material3.TextButton(onClick: {
                focusManager.clearFocus()
                amountFocused = false
            }) {
                androidx.compose.material3.Text("Done")
            }
        }
    }

    private var confirmButton: some View {
        Button {
            didSucceed = true
        } label: {
            Text("Confirm deposit")
                .font(Typography.semibold(theme.fontCallout))
                .foregroundStyle(theme.onAccent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: Layout.primaryActionHeight)
        .background(theme.accent)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMD))
        .disabled(!canConfirm)
    }

    fileprivate var amountChipRow: some View {
        HStack {
            ForEach(["10", "25", "50", "100"], id: \.self) { chip in
                Button {
                    amountText = chip
                } label: {
                    Text("€\(chip)")
                        .font(Typography.medium(theme.fontCaption))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: Layout.secondaryActionHeight)
                .background(theme.surfaceElevated)
                .foregroundStyle(theme.accent)
                .clipShape(Capsule())
            }
        }
    }

    fileprivate var successIcon: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(Typography.body(64.0))
            .foregroundStyle(theme.positive)
    }

    fileprivate var secondaryDoneButton: some View {
        Button("Done") { onResult(DepositResult.completed(amount: parsedAmount)) }
            .font(Typography.semibold(theme.fontCallout))
            .foregroundStyle(theme.onAccent)
            .padding(.horizontal, Layout.secondaryActionPadding)
            .frame(height: Layout.secondaryActionHeight)
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

    fileprivate func summaryRow(_ label: String, _ value: String) -> some View {
        LabeledContent(label, value: value)
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

    fileprivate func successChrome(_ content: some View) -> some View {
        content.transition(.scale(scale: 0.92).combined(with: .opacity))
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

    fileprivate var successIcon: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(Typography.body(64.0))
            .foregroundStyle(theme.positive)
            .symbolEffect(.bounce, options: .nonRepeating)
    }

    fileprivate var secondaryDoneButton: some View {
        Button {
            onResult(DepositResult.completed(amount: parsedAmount))
        } label: {
            Text("Done")
                .font(.headline)
                .foregroundStyle(theme.onAccent)
                .padding(.horizontal, Layout.secondaryActionPadding)
                .frame(height: Layout.secondaryActionHeight)
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
        .padding(.bottom, Layout.actionBarGap)
        .animation(.snappy(duration: 0.25), value: amountFocused)
    }

    private var primaryConfirmButton: some View {
        Button(action: onConfirm) {
            Text("Confirm deposit")
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
