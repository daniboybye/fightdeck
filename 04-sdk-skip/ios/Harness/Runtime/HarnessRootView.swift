//
// HarnessRootView.swift
// FightDeckHarnessRuntime
//
// Created by FightDeck on 12.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import SwiftUI

// Runtime stage: FightDeckCore linked, no feature SDK. This is the baseline the two
// feature stages are subtracted from, so it has to exercise the core rather than merely
// link it — an unreferenced package is dead-stripped and would weigh nothing.
struct HarnessRootView: View {
    private static let slipState = FightCore(bouts: []).slipState(
        slip: BetSlip(mode: BetMode.single, selections: [], stake: Money.parse("10.00")),
        balance: Money.parse("500.00")
    )

    var body: some View {
        Text(Money.formatCurrency(Self.slipState.potentialReturn))
    }
}
