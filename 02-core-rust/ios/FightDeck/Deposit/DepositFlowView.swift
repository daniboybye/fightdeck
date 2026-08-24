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
                PresetChipRow {
                    ForEach(["10", "25", "50", "100"], id: \.self) { chip in
                        PresetChipButton(title: "€\(chip)") { amountText = chip }
                    }
                }
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
                LabeledContent("Amount", value: DepositMoney.formatCurrency(parsedAmount))
                LabeledContent("Fee", value: DepositMoney.formatCurrency(feeAmount))
                LabeledContent("Total") {
                    Text(DepositMoney.formatCurrency(parsedAmount + feeAmount))
                        .fontWeight(.semibold)
                }
                LabeledContent("New balance", value: DepositMoney.formatCurrency(params.currentBalance + parsedAmount))
            }
        }
        // A bar rather than a plain inset: the form keeps scrolling under it, and Done sits
        // beside the action instead of in a keyboard toolbar that would overlap it.
        .safeAreaBar(edge: .bottom) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                PrimaryActionButton(
                    title: "Confirm deposit",
                    isEnabled: amountValidationMessage == nil && !amountText.isEmpty
                ) {
                    withAnimation(.smooth(duration: 0.35)) { didSucceed = true }
                }
                if amountFocused {
                    KeyboardDoneButton { amountFocused = false }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            // Whatever the bar is currently sitting on — home indicator or keyboard — it
            // should not look welded to it.
            .padding(.bottom, DesignTokens.Layout.actionBarGap)
            .animation(.snappy(duration: 0.25), value: amountFocused)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var successContent: some View {
        ContentUnavailableView {
            Label {
                Text("Deposit successful")
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DesignTokens.ColorToken.positive)
                    .symbolEffect(.bounce, options: .nonRepeating)
            }
        } description: {
            Text("New balance: \(DepositMoney.formatCurrency(params.currentBalance + parsedAmount))")
        } actions: {
            SecondaryActionButton(title: "Done") { onResult(.completed(amount: parsedAmount)) }
        }
        .sensoryFeedback(.success, trigger: didSucceed)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    private var parsedAmount: Decimal {
        DepositMoney.parse(amountText.isEmpty ? "0" : amountText)
    }

    private var feeAmount: Decimal {
        DepositMoney.money(parsedAmount * method.feeRate)
    }

    private var amountValidationMessage: String? {
        let amount = parsedAmount
        if amountText.isEmpty { return nil }
        if amount < 10 { return "Minimum deposit is €10" }
        if amount > 2_000 { return "Maximum deposit is €2,000" }
        return nil
    }
}
