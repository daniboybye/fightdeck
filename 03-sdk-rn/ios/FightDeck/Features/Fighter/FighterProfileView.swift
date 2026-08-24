//
// FighterProfileView.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI

struct FighterProfileView: View {
    @Bindable var state: AppState
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

    private func profile(_ fighter: FighterItem) -> some View {
        List {
            Section {
                hero(fighter)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section("Profile") {
                LabeledContent("Record", value: fighter.recordDisplay)
                LabeledContent("Wins", value: "\(fighter.record.wins)")
                LabeledContent("Losses", value: "\(fighter.record.losses)")
                if fighter.record.noContests > 0 {
                    LabeledContent("No contests", value: "\(fighter.record.noContests)")
                }
            }
            Section("Physicals") {
                if let height = fighter.heightCm {
                    LabeledContent("Height", value: "\(height) cm")
                }
                if let reach = fighter.reachIn {
                    LabeledContent("Reach", value: "\(reach) in")
                }
                if let stance = fighter.stance {
                    LabeledContent("Stance", value: stance.localizedCapitalized)
                }
                if let country = fighter.country {
                    LabeledContent("Country", value: country)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    /// The portrait carries the screen the way it does in Photos: full bleed, with the name
    /// sitting on a scrim over the image instead of in a caption below it.
    private func hero(_ fighter: FighterItem) -> some View {
        RemoteImage(url: state.imageURL(fighter.portrait))
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
