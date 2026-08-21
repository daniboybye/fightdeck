//
// FighterProfileView.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import SwiftUI

struct FighterProfileView: View {
    @Bindable var state: AppState
    let fighterID: String

    var body: some View {
        Group {
            if let fighter = fighter {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        hero(fighter)
                        statsGrid(fighter)
                        boutsSection(fighter)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(fighter?.name ?? "Fighter")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var fighter: FighterItem? {
        if case .loaded(let fighters) = state.fightersState {
            return fighters.first { $0.id == fighterID }
        }
        return nil
    }

    private func hero(_ fighter: FighterItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: state.imageURL(fighter.portrait))
                .frame(height: 220)
                .clipped()
            LinearGradient(colors: [.clear, DesignTokens.ColorToken.background], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading) {
                Text(fighter.name)
                    .font(.system(size: DesignTokens.FontSize.headline, weight: .bold))
                if let nickname = fighter.nickname {
                    Text("\"\(nickname)\"")
                        .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
    }

    private func statsGrid(_ fighter: FighterItem) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignTokens.Spacing.md) {
            stat("Record", fighter.recordDisplay)
            stat("Height", fighter.heightCm.map { "\($0) cm" } ?? "—")
            stat("Reach", fighter.reachIn.map { "\($0) in" } ?? "—")
            stat("Stance", fighter.stance?.capitalized ?? "—")
            stat("Country", fighter.country ?? "—")
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.system(size: DesignTokens.FontSize.caption))
                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            Text(value)
                .font(.system(size: DesignTokens.FontSize.callout, weight: .medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func boutsSection(_ fighter: FighterItem) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Bouts on these cards")
                .font(.system(size: DesignTokens.FontSize.callout, weight: .semibold))
                .padding(.horizontal, DesignTokens.Spacing.lg)
            if case .loaded(let events) = state.eventsState {
                ForEach(relevantBouts(events: events, fighterID: fighter.id), id: \.bout.id) { pair in
                    HStack {
                        Text(pair.event.name)
                            .font(.system(size: DesignTokens.FontSize.caption))
                            .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                        Spacer()
                        Text(pair.bout.result.winnerId == fighter.id ? "Win" : "Loss")
                            .foregroundStyle(
                                pair.bout.result.winnerId == fighter.id
                                    ? DesignTokens.ColorToken.positive
                                    : DesignTokens.ColorToken.negative
                            )
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                }
            }
        }
    }

    private func relevantBouts(events: [EventItem], fighterID: String) -> [(event: EventItem, bout: BoutItem)] {
        events.flatMap { event in
            event.bouts
                .filter { $0.redCorner.fighterId == fighterID || $0.blueCorner.fighterId == fighterID }
                .map { (event, $0) }
        }
    }
}
