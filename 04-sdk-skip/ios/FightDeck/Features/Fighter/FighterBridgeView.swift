//
// FighterBridgeView.swift
// FightDeck
//
// Created by FightDeck on 13.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import FightDeckFighter
import SwiftUI

struct FighterBridgeView: View {
    let state: AppState
    let fighterID: String

    var body: some View {
        Group {
            if let fighter = state.catalog.fighter(fighterID) {
                FighterRootView(
                    params: FighterParams(
                        fighter: fighter,
                        portraitURL: state.imageURL(fighter.portrait)?.absoluteString ?? ""
                    )
                )
            } else {
                ProgressView()
            }
        }
        .navigationTitle(state.catalog.fighter(fighterID)?.name ?? "Fighter")
        .navigationBarTitleDisplayMode(.inline)
    }
}
