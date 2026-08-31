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
    static let minTapTarget: CGFloat = 44
    static let primaryActionHeight: CGFloat = 44
    static let secondaryActionHeight: CGFloat = 44
    static let secondaryActionPadding: CGFloat = 24
    static let actionBarGap: CGFloat = 12
    static let betSlipAccessoryHeight: CGFloat = 44
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
        Group {
            if didSucceed {
                successContent
            } else {
                formContent
            }
        }
        .navigationTitle(didSucceed ? "Confirmed" : "Deposit")
        .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.inline)
        // The money has already moved by the time this screen appears, so going back to the
        // amount field would offer to spend it a second time.
        .navigationBarBackButtonHidden(didSucceed)
    }

    // One screen rather than an amount/method/confirm wizard: the whole flow is four fields
    // and stepping through them only hides the total from the person approving it.
    private var formContent: some View {
        #if SKIP
        skipFormContent
        #else
        formScroll
            .modifier(DepositBottomBarModifier(
                theme: theme,
                amountFocused: amountFocused,
                isEnabled: amountValidationMessage == nil && !amountText.isEmpty,
                onConfirm: { withAnimation(.smooth(duration: 0.35)) { didSucceed = true } },
                onDismissKeyboard: { amountFocused = false }
            ))
        #endif
    }

    #if SKIP
    private var skipFormContent: some View {
        ScrollView {
            VStack(alignment: HorizontalAlignment.leading, spacing: theme.spacingLG) {
                amountSection
                methodSection
                summarySection
                Button {
                    didSucceed = true
                } label: {
                    Text("Confirm deposit")
                        .font(Typography.semibold(theme.fontCallout))
                        .foregroundStyle(theme.onAccent)
                        .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
                }
                .frame(height: Layout.primaryActionHeight)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMD))
                .disabled(amountValidationMessage != nil || amountText.isEmpty)
            }
            .padding(theme.spacingLG)
        }
        .toolbar {
            ToolbarItemGroup(placement: ToolbarItemPlacement.keyboard) {
                Spacer()
                Button("Done") { amountFocused = false }
            }
        }
    }
    #endif

    private var formScroll: some View {
        ScrollView {
            VStack(alignment: HorizontalAlignment.leading, spacing: theme.spacingLG) {
                amountSection
                methodSection
                summarySection
            }
            .padding(theme.spacingLG)
        }
    }

    private var amountSection: some View {
        VStack(alignment: HorizontalAlignment.leading, spacing: theme.spacingMD) {
            Text("Amount")
                .font(Typography.semibold(theme.fontCallout))
                .foregroundStyle(theme.textPrimary)
            TextField("€0.00", text: $amountText)
                .keyboardType(UIKeyboardType.decimalPad)
                .font(Typography.bold(theme.fontDisplay))
                .focused($amountFocused)
                .padding(theme.spacingLG)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusLG))

            if let message = amountValidationMessage {
                Text(message)
                    .foregroundStyle(theme.negative)
                    .font(Typography.body(theme.fontCaption))
            }

            amountChipRow
        }
    }

    @ViewBuilder
    private var amountChipRow: some View {
        #if SKIP
        HStack {
            ForEach(["10", "25", "50", "100"], id: \.self) { chip in
                amountChip("€\(chip)") { amountText = chip }
            }
        }
        #else
        PresetChipRow(theme: theme.chipTheme) {
            ForEach(["10", "25", "50", "100"], id: \.self) { chip in
                PresetChipButton(title: "€\(chip)", theme: theme.chipTheme) { amountText = chip }
            }
        }
        #endif
    }

    private var methodSection: some View {
        VStack(alignment: HorizontalAlignment.leading, spacing: theme.spacingSM) {
            Text("Method")
                .font(Typography.semibold(theme.fontCallout))
                .foregroundStyle(theme.textPrimary)
            ForEach(DepositMethod.allCases) { item in
                Button {
                    method = item
                } label: {
                    HStack {
                        Image(systemName: method == item ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(theme.accent)
                        VStack(alignment: HorizontalAlignment.leading) {
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
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: HorizontalAlignment.leading, spacing: theme.spacingMD) {
            Text("Summary")
                .font(Typography.semibold(theme.fontCallout))
                .foregroundStyle(theme.textPrimary)
            summaryRow("Amount", Money.formatCurrency(parsedAmount))
            summaryRow("Method", method.title)
            summaryRow("Fee", Money.formatCurrency(feeAmount))
            summaryRow("Total", Money.formatCurrency(parsedAmount + feeAmount))
            summaryRow("New balance", Money.formatCurrency(params.currentBalance + parsedAmount))
        }
        .padding(theme.spacingLG)
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusLG))
    }

    private var successContent: some View {
        VStack(spacing: theme.spacingLG) {
            successIcon
            Text("Deposit successful")
                .font(Typography.bold(theme.fontTitle))
            Text("New balance: \(Money.formatCurrency(params.currentBalance + parsedAmount))")
                .foregroundStyle(theme.textSecondary)
            secondaryDoneButton
        }
        .padding(theme.spacingXL)
        #if !SKIP
        .modifier(SuccessPresentationModifier(trigger: didSucceed))
        #endif
    }

    @ViewBuilder
    private var successIcon: some View {
        #if !SKIP
        if #available(iOS 18, *) {
            Image(systemName: "checkmark.circle.fill")
                .font(Typography.body(64.0))
                .foregroundStyle(theme.positive)
                .symbolEffect(.bounce, options: .nonRepeating)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(Typography.body(64.0))
                .foregroundStyle(theme.positive)
        }
        #else
        Image(systemName: "checkmark.circle.fill")
            .font(Typography.body(64.0))
            .foregroundStyle(theme.positive)
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

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(theme.textPrimary)
        }
    }

    @ViewBuilder
    private var secondaryDoneButton: some View {
        #if SKIP
        Button("Done") { onResult(DepositResult.completed(amount: parsedAmount)) }
            .font(Typography.semibold(theme.fontCallout))
            .foregroundStyle(theme.onAccent)
            .padding(.horizontal, Layout.secondaryActionPadding)
            .frame(height: Layout.secondaryActionHeight)
            .background(theme.accent)
            .clipShape(Capsule())
        #else
        Group {
            if #available(iOS 26, *) {
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
            } else {
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
    }

    @ViewBuilder
    private func amountChip(_ title: String, action: @escaping () -> Void) -> some View {
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
private struct DepositBottomBarModifier: ViewModifier {
    let theme: ThemeTokens
    let amountFocused: Bool
    let isEnabled: Bool
    let onConfirm: () -> Void
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

    @ViewBuilder
    private var primaryConfirmButton: some View {
        if #available(iOS 26, *) {
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
        } else {
            Button(action: onConfirm) {
                Text("Confirm deposit")
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
#endif

#if !SKIP
private struct SuccessPresentationModifier: ViewModifier {
    let trigger: Bool

    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content
                .sensoryFeedback(.success, trigger: trigger)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
        } else {
            content
        }
    }
}
#endif
