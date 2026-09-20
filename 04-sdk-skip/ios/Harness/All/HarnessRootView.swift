//
// HarnessRootView.swift
// FightDeckHarnessAll
//
// Created by FightDeck on 13.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckBetslip
import FightDeckCore
import FightDeckDeposit
import FightDeckFighter
import SwiftUI

// Third-feature stage: core plus all three feature SDKs. Subtracting the both stage from
// this one is the third data point for "what does the next screen cost".
struct HarnessRootView: View {
    @State private var store = BetSlipStore(fightCore: FightCore(bouts: []))

    var body: some View {
        TabView {
            DepositFlowView(
                params: DepositParams(currentBalance: Money.parse("500.00")),
                theme: ThemeTokens.defaults,
                onResult: { _ in }
            )
            BetSlipRootView(
                store: store,
                display: HarnessSlipDisplay(),
                theme: ThemeTokens.defaults,
                onDeposit: {},
                onBrowseEvents: {},
                onHostSync: { _, _, _ in }
            )
            FighterRootView(
                params: FighterParams(
                    fighter: Fighter(
                        id: "sample",
                        name: "Sample Fighter",
                        nickname: nil,
                        country: nil,
                        heightCm: nil,
                        reachIn: nil,
                        stance: nil,
                        record: FighterRecord(wins: 20, losses: 2, draws: 0, noContests: 0, display: "20-2-0"),
                        portrait: "assets/fighters/sample.jpg"
                    ),
                    portraitURL: ""
                ),
                theme: ThemeTokens.defaults
            )
        }
    }
}

@MainActor
private final class HarnessSlipDisplay: SlipDisplayContext {
    func fighterName(id: String) -> String { id }
    func opponentName(for selection: Selection) -> String { selection.fighterID }
    func eventName(for selection: Selection) -> String { selection.boutID }
}
