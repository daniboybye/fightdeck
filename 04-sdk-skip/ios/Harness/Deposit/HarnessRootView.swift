//
// HarnessRootView.swift
// FightDeckHarnessDeposit
//
// Created by FightDeck on 12.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import FightDeckDeposit
import SwiftUI

// First-feature stage: core plus the deposit SDK. Mounting the real DepositFlowView is the
// point — this is where SkipUI enters the binary, and SkipUI is most of what the first
// feature costs.
struct HarnessRootView: View {
    var body: some View {
        DepositFlowView(
            params: DepositParams(currentBalance: Money.parse("500.00")),
            onResult: { _ in }
        )
    }
}
