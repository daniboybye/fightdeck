//
// FighterBridgeView.swift
// FightDeck
//
// Created by FightDeck on 13.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckFighter
import SwiftUI

struct FighterBridgeView: View {
    @Bindable var state: AppState
    let fighterID: String

    var body: some View {
        Group {
            if state.fighter(fighterID) != nil {
                FighterRootView(
                    params: fighterParams(),
                    theme: FighterTheme.parse(ThemeLoader.tokensJSON())
                )
            } else {
                ProgressView()
            }
        }
        .navigationTitle(state.fighter(fighterID)?.name ?? "Fighter")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func fighterParams() -> FighterParams {
        let fighter = state.fighter(fighterID)
        let fighterJSON = fighter.flatMap { try? String(data: JSONEncoder().encode($0), encoding: .utf8) } ?? "{}"
        let portraitURL = fighter.flatMap { state.imageURL($0.portrait)?.absoluteString } ?? ""
        return FighterParams(
            themeJSON: ThemeLoader.tokensJSON(),
            fighterJSON: fighterJSON,
            portraitURL: portraitURL
        )
    }
}
