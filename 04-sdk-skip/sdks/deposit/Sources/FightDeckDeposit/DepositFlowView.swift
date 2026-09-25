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

struct DepositFlowView: View {
    let params: DepositParams
    let onResult: @Sendable (DepositResult) -> Void

    @Environment(\.fightDeckTheme) private var theme: ThemeTokens
    @State private var amountText = ""
    @State private var method = DepositMethod.card
    @State private var didSucceed = false
    @FocusState private var amountFocused: Bool

    init(params: DepositParams, onResult: @escaping @Sendable (DepositResult) -> Void) {
        self.params = params
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

    var body: some View {
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
        .modifier(FightDeckScreen(theme: theme))
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

    /// The confirmation replaces the form it sits on.
    private var successContent: some View {
        VStack(spacing: theme.spacingLG) {
            successIcon
            Text("Deposit successful")
                .font(Typography.bold(theme.fontTitle))
            Text("New balance: \(Money.formatCurrency(params.currentBalance + parsedAmount))")
                .foregroundStyle(theme.textSecondary)
            doneButton
        }
        .padding(theme.spacingXL)
        .modifier(ConfirmationTransition())
    }

    // The confirm button rides above the form rather than at the end of it, the same shape the
    // slip uses: as the last row of a scroll it ends up behind the keyboard the amount field
    // raises, and on Android the scroll view will not extend its range far enough to reach it.
    //
    // `.filled` on Android because this screen's native counterpart puts the row on a solid
    // strip the form scrolls under; the slip's floats, so that its selections pill below reads
    // as part of the same bar.
    private var formContent: some View {
        depositForm
            .modifier(InsetGroupedList(theme: theme))
            .modifier(PinnedActionBar(ActionBar(
                "Confirm deposit",
                isEnabled: canConfirm,
                showsDone: amountFocused,
                style: ActionBarStyle.filled,
                theme: theme,
                onPrimary: { didSucceed = true },
                onDone: { amountFocused = false }
            )))
    }

    // MARK: - The core's controls
    //
    // Each reached through a function or property, never as a bare initialiser in a
    // `@ViewBuilder`, which `skipstone` would drop (see `GroupedList.swift`).

    private func sectionTitle(_ title: String) -> some View {
        SectionHeader(title, theme: theme)
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        LabeledRow(theme: theme, label: label, value: value, valueStyle: theme.textPrimary)
    }

    private var successIcon: some View {
        ConfirmationIcon(size: 64.0, theme: theme)
    }

    private var doneButton: some View {
        SecondaryActionButton("Done", theme: theme) {
            onResult(DepositResult.completed(amount: parsedAmount))
        }
    }

    /// The core's chip row, reached through a property rather than written bare into the
    /// section's builder, which `skipstone` would drop (see `GroupedList.swift`).
    private var amountChipRow: some View {
        PresetChipRow(values: ["10", "25", "50", "100"], theme: theme.chipTheme) { value in
            amountText = value
        }
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

    /// Compose supplies the screen's own chrome and animates its own state changes; the palette
    /// comes from `FightDeckScreen` on the body.
    fileprivate func platformChrome(_ content: some View) -> some View {
        content
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
}
#endif
