//
// DepositFlowView.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI

enum DepositMethod: String, CaseIterable, Identifiable {
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
        case .wallet: .init(string: "0.01")!
        }
    }
}

@Observable
@MainActor
final class DepositFormModel {
    static let minimumAmount = Decimal(10)
    static let maximumAmount = Decimal(2_000)

    var amountText = ""
    var method = DepositMethod.card
    private(set) var didSucceed = false

    var amount: Decimal {
        Money.parse(amountText.isEmpty ? "0" : amountText)
    }

    var fee: Decimal {
        Money.money(amount * method.feeRate)
    }

    var total: Decimal {
        amount + fee
    }

    var validationMessage: String? {
        if amountText.isEmpty { return nil }
        if amount < Self.minimumAmount { return "Minimum deposit is €10" }
        if amount > Self.maximumAmount { return "Maximum deposit is €2,000" }
        return nil
    }

    var canConfirm: Bool {
        !amountText.isEmpty && validationMessage == nil
    }

    func confirm() {
        didSucceed = true
    }
}

struct DepositFlowView: View {
    let params: DepositParams
    let onResult: DepositResultHandler

    @State private var form = DepositFormModel()
    @FocusState private var amountFocused: Bool

    var body: some View {
        Group {
            if form.didSucceed {
                successContent
            } else {
                formContent
            }
        }
        // Nothing to name once it has happened: the confirmation says so in the middle of the
        // screen, where the eye already is, and a title would only repeat it in the corner.
        .navigationTitle(form.didSucceed ? "" : "Deposit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // The money has already moved by the time the confirmation shows, so that screen
            // leaves through Done only: closing it would offer to spend the deposit twice.
            if !form.didSucceed {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") { onResult(.cancelled) }
                }
            }
        }
    }

    private var formContent: some View {
        Form {
            amountSection
            methodSection
            summarySection
        }
        .safeAreaBar(edge: .bottom) { actionBar }
        .scrollDismissesKeyboard(.interactively)
    }

    private var amountSection: some View {
        Section("Amount") {
            TextField("€10 – €2,000", text: $form.amountText)
                .keyboardType(.decimalPad)
                .font(.largeTitle.bold())
                .focused($amountFocused)
            if let message = form.validationMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.ColorToken.negative)
            }
            PresetChipRow {
                ForEach(["10", "25", "50", "100"], id: \.self) { chip in
                    PresetChipButton(title: "€\(chip)") { form.amountText = chip }
                }
            }
        }
    }

    private var methodSection: some View {
        Section("Method") {
            Picker("Method", selection: $form.method) {
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
    }

    private var summarySection: some View {
        Section("Summary") {
            LabeledContent("Amount", value: Money.formatCurrency(form.amount))
            LabeledContent("Fee", value: Money.formatCurrency(form.fee))
            LabeledContent("Total") {
                Text(Money.formatCurrency(form.total))
                    .fontWeight(.semibold)
            }
            LabeledContent("New balance", value: Money.formatCurrency(newBalance))
        }
    }

    private var actionBar: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            PrimaryActionButton(title: "Confirm deposit", isEnabled: form.canConfirm) {
                withAnimation(.smooth(duration: 0.35)) { form.confirm() }
            }
            if amountFocused {
                KeyboardDoneButton { amountFocused = false }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.bottom, DesignTokens.Layout.actionBarGap)
        .animation(.snappy(duration: 0.25), value: amountFocused)
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
            Text("New balance: \(Money.formatCurrency(newBalance))")
        } actions: {
            SecondaryActionButton(title: "Done") { onResult(.completed(amount: form.amount)) }
        }
        .sensoryFeedback(.success, trigger: form.didSucceed)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    private var newBalance: Decimal {
        params.currentBalance + form.amount
    }
}
