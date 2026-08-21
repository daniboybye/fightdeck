//
// DepositFlowView.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import SwiftUI

struct DepositFlowView: View {
    let params: DepositParams
    let onResult: @Sendable (DepositResult) -> Void

    @State private var step = 0
    @State private var amountText = ""
    @State private var method = DepositMethod.card
    @State private var phase: DepositPhase = .form

    private enum DepositPhase {
        case form
        case success
        case failure
    }

    private enum DepositMethod: String, CaseIterable, Identifiable {
        case card
        case bank
        case wallet

        var id: String { rawValue }

        var title: String {
            switch self {
            case .card: "Card"
            case .bank: "Bank transfer"
            case .wallet: "Wallet"
            }
        }

        var feeNote: String {
            switch self {
            case .card: "Instant · 0% fee"
            case .bank: "1–2 days · 0% fee"
            case .wallet: "Instant · 1% fee"
            }
        }

        var feeRate: Decimal {
            switch self {
            case .card, .bank: 0
            case .wallet: Decimal(string: "0.01")!
            }
        }
    }

    var body: some View {
        ZStack {
            DesignTokens.ColorToken.background.ignoresSafeArea()
            switch phase {
            case .form:
                formContent
            case .success:
                successContent
            case .failure:
                failureContent
            }
        }
        .navigationTitle("Deposit")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Balance: \(Money.formatCurrency(params.currentBalance))")
                .font(.system(size: DesignTokens.FontSize.body))
                .foregroundStyle(DesignTokens.ColorToken.textSecondary)

            Picker("Step", selection: $step) {
                Text("Amount").tag(0)
                Text("Method").tag(1)
                Text("Confirm").tag(2)
            }
            .pickerStyle(.segmented)

            switch step {
            case 0:
                amountStep
            case 1:
                methodStep
            default:
                confirmStep
            }

            Spacer()
            primaryButton
        }
        .padding(DesignTokens.Spacing.lg)
    }

    private var amountStep: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            TextField("€0.00", text: $amountText)
                .keyboardType(.decimalPad)
                .font(.system(size: DesignTokens.FontSize.display, weight: .bold))
                .padding(DesignTokens.Spacing.lg)
                .background(DesignTokens.ColorToken.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))

            if let message = amountValidationMessage {
                Text(message)
                    .foregroundStyle(DesignTokens.ColorToken.negative)
                    .font(.system(size: DesignTokens.FontSize.caption))
            }

            HStack {
                ForEach(["10", "25", "50", "100"], id: \.self) { chip in
                    Button("€\(chip)") { amountText = chip }
                        .buttonStyle(ChipButtonStyle())
                }
            }
        }
    }

    private var methodStep: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(DepositMethod.allCases) { item in
                Button {
                    method = item
                } label: {
                    HStack {
                        Image(systemName: method == item ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(DesignTokens.ColorToken.accent)
                        VStack(alignment: .leading) {
                            Text(item.title)
                                .foregroundStyle(DesignTokens.ColorToken.textPrimary)
                            Text(item.feeNote)
                                .font(.system(size: DesignTokens.FontSize.caption))
                                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(DesignTokens.Spacing.lg)
                    .background(DesignTokens.ColorToken.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
                }
            }
        }
    }

    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            summaryRow("Amount", Money.formatCurrency(parsedAmount))
            summaryRow("Method", method.title)
            summaryRow("Fee", Money.formatCurrency(feeAmount))
            summaryRow("Total", Money.formatCurrency(parsedAmount + feeAmount))
        }
        .padding(DesignTokens.Spacing.lg)
        .background(DesignTokens.ColorToken.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }

    private var successContent: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(DesignTokens.ColorToken.positive)
            Text("Deposit successful")
                .font(.system(size: DesignTokens.FontSize.title, weight: .bold))
            Text("New balance: \(Money.formatCurrency(params.currentBalance + parsedAmount))")
                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            Button("Done") { onResult(.completed(amount: parsedAmount)) }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(DesignTokens.Spacing.xl)
    }

    private var failureContent: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Deposit failed")
                .foregroundStyle(DesignTokens.ColorToken.negative)
            Button("Retry") { phase = .form }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        if step < 2 {
            Button(step == 0 ? "Continue" : "Review") {
                if step == 0, amountValidationMessage != nil { return }
                step += 1
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(step == 0 && amountValidationMessage != nil)
        } else {
            Button("Confirm deposit") {
                if parsedAmount >= 10, parsedAmount <= 2_000 {
                    phase = .success
                } else {
                    phase = .failure
                }
            }
            .buttonStyle(PrimaryButtonStyle())
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
        if amount < 10 { return "Minimum deposit is €10" }
        if amount > 2_000 { return "Maximum deposit is €2,000" }
        return nil
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(DesignTokens.ColorToken.textPrimary)
        }
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: DesignTokens.FontSize.callout, weight: .semibold))
            .foregroundStyle(DesignTokens.ColorToken.onAccent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(DesignTokens.ColorToken.accent.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }
}

private struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: DesignTokens.FontSize.caption, weight: .medium))
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(DesignTokens.ColorToken.surfaceElevated)
            .foregroundStyle(DesignTokens.ColorToken.accent)
            .clipShape(Capsule())
    }
}
