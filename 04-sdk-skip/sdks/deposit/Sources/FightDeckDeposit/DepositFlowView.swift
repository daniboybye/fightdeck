//
// DepositFlowView.swift
// FightDeckDeposit
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import FightDeckCore
import SwiftUI

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
        ScrollView {
            VStack(alignment: HorizontalAlignment.leading, spacing: theme.spacingLG) {
                amountSection
                methodSection
                summarySection

                Button("Confirm deposit") { didSucceed = true }
                    .font(Typography.semibold(theme.fontCallout))
                    .foregroundStyle(theme.onAccent)
                    .frame(maxWidth: CGFloat.infinity, minHeight: 52)
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

            HStack {
                ForEach(["10", "25", "50", "100"], id: \.self) { chip in
                    Button("€\(chip)") { amountText = chip }
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
            Image(systemName: "checkmark.circle.fill")
                .font(Typography.body(64))
                .foregroundStyle(theme.positive)
            Text("Deposit successful")
                .font(Typography.bold(theme.fontTitle))
            Text("New balance: \(Money.formatCurrency(params.currentBalance + parsedAmount))")
                .foregroundStyle(theme.textSecondary)
            Button("Done") { onResult(DepositResult.completed(amount: parsedAmount)) }
                .font(Typography.semibold(theme.fontCallout))
                .foregroundStyle(theme.onAccent)
                .frame(maxWidth: CGFloat.infinity, minHeight: 52)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMD))
        }
        .padding(theme.spacingXL)
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
}
