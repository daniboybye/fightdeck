//
// FighterBridgeView.swift
// FightDeck
//
// Created by FightDeck on 13.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FighterSDK
import FightDeckRNRuntime
import SwiftUI

struct FighterBridgeView: View {
    let state: AppState
    let fighterID: String

    var body: some View {
        Group {
            if state.fighter(fighterID) != nil {
                RNSurfaceView {
                    SDKBootstrap.shared.fighterHosting.makeViewController(params: params)
                } update: {
                    SDKBootstrap.shared.fighterHosting.update(params: params)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(state.fighter(fighterID)?.name ?? "Fighter")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var params: FighterParams {
        let fighter = state.fighter(fighterID)
        // Sorted: the encoder's key order changes between calls, and an unchanged fighter has
        // to read as unchanged or the adapter pushes it to React again.
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let fighterJSON = fighter.flatMap { try? String(data: encoder.encode($0), encoding: .utf8) } ?? "{}"
        let portraitURL = fighter.flatMap { state.imageURL($0.portrait)?.absoluteString } ?? ""
        return FighterParams(
            fighterJSON: fighterJSON,
            portraitURL: portraitURL
        )
    }
}
