//
// FighterProfileView.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightEvents
import SwiftUI

struct FighterProfileView: View {
    let state: AppState
    let fighterID: String

    var body: some View {
        Group {
            if let fighter = state.fighter(fighterID) {
                profile(fighter)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(state.fighter(fighterID)?.name ?? "Fighter")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func profile(_ fighter: FighterSummary) -> some View {
        List {
            Section {
                hero(fighter)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section("Profile") {
                ForEach(fighter.profileRows, id: \.label) { row in
                    LabeledContent(row.label, value: row.value)
                }
            }
            Section("Physicals") {
                ForEach(fighter.physicalRows, id: \.label) { row in
                    LabeledContent(row.label, value: row.value)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    /// The portrait carries the screen the way it does in Photos: full bleed, with the name
    /// sitting on a scrim over the image instead of in a caption below it.
    private func hero(_ fighter: FighterSummary) -> some View {
        RemoteImage(url: state.imageURL(fighter.portraitPath))
            .frame(height: 320)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(fighter.name)
                        .font(.largeTitle.bold())
                    if let nickname = fighter.nickname {
                        Text("“\(nickname)”")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Text(fighter.recordDisplay)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DesignTokens.ColorToken.accent)
                }
                .padding(DesignTokens.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 200)
                    .allowsHitTesting(false)
                }
            }
    }
}
