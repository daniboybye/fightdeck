//
// DepositTests.swift
// FightCoreTests
//
// Created by FightDeck on 24.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation
import Testing
@testable import FightCore

@Suite("Deposit")
struct DepositTests {
    @Test("the wallet fee rounds half-up and is charged on top")
    func walletFee() {
        let quote = Deposit.quote(amountText: "10.50", method: .wallet, balance: 500)
        #expect(quote.fee == Decimal(string: "0.11"))
        #expect(quote.total == Decimal(string: "10.61"))
        #expect(quote.newBalance == Decimal(string: "510.50"))
    }

    @Test("card and bank transfer are free")
    func freeMethods() {
        #expect(Deposit.quote(amountText: "100", method: .card, balance: 0).fee == 0)
        #expect(Deposit.quote(amountText: "100", method: .bank, balance: 0).fee == 0)
    }

    @Test("limits include both ends")
    func limits() {
        #expect(Deposit.quote(amountText: "10", method: .card, balance: 0).validationMessage == nil)
        #expect(Deposit.quote(amountText: "2000", method: .card, balance: 0).validationMessage == nil)
        #expect(
            Deposit.quote(amountText: "9.99", method: .card, balance: 0).validationMessage
                == "Minimum deposit is €10"
        )
        #expect(
            Deposit.quote(amountText: "2000.01", method: .card, balance: 0).validationMessage
                == "Maximum deposit is €2,000"
        )
    }

    @Test("a decimal comma reads as a point")
    func decimalComma() {
        let quote = Deposit.quote(amountText: "10,50", method: .card, balance: 500)
        #expect(quote.amount == Decimal(string: "10.50"))
        #expect(quote.validationMessage == nil)
    }

    @Test("an empty field is not an error but cannot be confirmed")
    func emptyField() {
        let quote = Deposit.quote(amountText: "", method: .card, balance: 500)
        #expect(quote.validationMessage == nil)
        #expect(!quote.canConfirm)
        #expect(quote.newBalance == 500)
    }
}
