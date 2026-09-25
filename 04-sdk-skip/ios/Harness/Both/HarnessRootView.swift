//
// HarnessRootView.swift
// FightDeckHarnessBoth
//
// Created by FightDeck on 12.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckBetslip
import FightDeckCore
import FightDeckDeposit
import SwiftUI

// Second-feature stage: core plus both feature SDKs. Subtracting the deposit stage from
// this one is the "what does the next screen cost" number, and it comes out small because
// the bet slip reuses the SkipUI the deposit screen already paid for.
struct HarnessRootView: View {
    @State private var store = BetSlipStore(fightCore: FightCore(bouts: []))

    var body: some View {
        TabView {
            DepositFlowView(
                params: DepositParams(currentBalance: Money.parse("500.00")),
                onResult: { _ in }
            )
            BetSlipRootView(
                store: store,
                display: CatalogSlipDisplay(events: [], fighters: []),
                onDeposit: {},
                onBrowseEvents: {}
            )
        }
    }
}
