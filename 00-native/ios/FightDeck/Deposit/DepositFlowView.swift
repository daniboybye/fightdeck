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

    @State private var amountText = ""
    @State private var method = DepositMethod.card
    @State private var didSucceed = false
    @FocusState private var amountFocused: Bool

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

        var symbol: String {
            switch self {
            case .card: "creditcard"
            case .bank: "building.columns"
            case .wallet: "wallet.bifold"
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
        Group {
            if didSucceed {
                successContent
            } else {
                formContent
            }
        }
        .navigationTitle(didSucceed ? "Confirmed" : "Deposit")
        .navigationBarTitleDisplayMode(.inline)
        // The money has already moved by the time this screen appears, so going back to the
        // amount field would offer to spend it a second time.
        .navigationBarBackButtonHidden(didSucceed)
    }

    // One screen rather than an amount/method/confirm wizard: the whole flow is four fields
    // and stepping through them only hides the total from the person approving it.
    private var formContent: some View {
        Form {
            Section("Amount") {
                TextField("€0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.largeTitle.bold())
                    .focused($amountFocused)
                if let message = amountValidationMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.ColorToken.negative)
                }
                HStack {
                    ForEach(["10", "25", "50", "100"], id: \.self) { chip in
                        Button("€\(chip)") { amountText = chip }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .frame(maxWidth: .infinity)
                    }
                }
                .tint(DesignTokens.ColorToken.accent)
            }

            Section("Method") {
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

            Section("Summary") {
                LabeledContent("Amount", value: Money.formatCurrency(parsedAmount))
                LabeledContent("Fee", value: Money.formatCurrency(feeAmount))
                LabeledContent("Total") {
                    Text(Money.formatCurrency(parsedAmount + feeAmount))
                        .fontWeight(.semibold)
                }
                LabeledContent("New balance", value: Money.formatCurrency(params.currentBalance + parsedAmount))
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                didSucceed = true
            } label: {
                Text("Confirm deposit")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(DesignTokens.ColorToken.accent)
            .disabled(amountValidationMessage != nil || amountText.isEmpty)
            .padding(DesignTokens.Spacing.lg)
            .background(.bar)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { amountFocused = false }
            }
        }
    }

    private var successContent: some View {
        ContentUnavailableView {
            Label("Deposit successful", systemImage: "checkmark.circle.fill")
        } description: {
            Text("New balance: \(Money.formatCurrency(params.currentBalance + parsedAmount))")
        } actions: {
            Button("Done") { onResult(.completed(amount: parsedAmount)) }
                .buttonStyle(.glassProminent)
                .tint(DesignTokens.ColorToken.accent)
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
}
