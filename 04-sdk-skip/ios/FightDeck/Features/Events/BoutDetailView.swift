//
// BoutDetailView.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import FightDeckCore
import SwiftUI

struct BoutDetailView: View {
    @Bindable var state: AppState
    let event: EventItem
    let bout: BoutItem
    @Binding var path: [EventsRoute]
    let mode: EventMode

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xl) {
                hero
                taleOfTheTape
                if mode.showsOdds {
                    market
                }
                if mode.showsResults {
                    resultPanel
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .navigationTitle("Bout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        ZStack {
            HStack(spacing: DesignTokens.Spacing.xl) {
                fighterHero(bout.redCorner, ring: DesignTokens.ColorToken.cornerRed)
                Text("VS")
                    .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                fighterHero(bout.blueCorner, ring: DesignTokens.ColorToken.cornerBlue)
            }
            .padding(DesignTokens.Spacing.xl)
        }
        .frame(maxWidth: .infinity)
        .glassEffect()
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }

    private func fighterHero(_ corner: CornerItem, ring: Color) -> some View {
        VStack {
            Circle()
                .stroke(ring, lineWidth: 3)
                .frame(width: 88, height: 88)
                .overlay {
                    RemoteImage(url: state.imageURL("assets/fighters/\(corner.fighterId).jpg"))
                        .clipShape(Circle())
                }
            Button(corner.name) {
                path.append(.fighter(corner.fighterId))
            }
            .font(.system(size: DesignTokens.FontSize.headline, weight: .bold))
            .foregroundStyle(DesignTokens.ColorToken.textPrimary)
        }
    }

    private var taleOfTheTape: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            tapeRow(left: record(bout.redCorner.fighterId), label: "RECORD", right: record(bout.blueCorner.fighterId))
            tapeRow(left: height(bout.redCorner.fighterId), label: "HEIGHT", right: height(bout.blueCorner.fighterId))
            tapeRow(left: reach(bout.redCorner.fighterId), label: "REACH", right: reach(bout.blueCorner.fighterId))
            tapeRow(left: stance(bout.redCorner.fighterId), label: "STANCE", right: stance(bout.blueCorner.fighterId))
            tapeRow(left: country(bout.redCorner.fighterId), label: "COUNTRY", right: country(bout.blueCorner.fighterId))
        }
        .cardStyle()
    }

    private var market: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            marketButton(bout.redCorner)
            marketButton(bout.blueCorner)
        }
    }

    private func marketButton(_ corner: CornerItem) -> some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            OddsButton(
                label: FightCoreDisplay.formatOdds(Money.parse(corner.closingOdds.decimal)),
                fractional: corner.closingOdds.fractional,
                isSelected: state.isSelected(boutID: bout.id, fighterID: corner.fighterId)
            ) {
                state.toggleSelection(bout: bout, fighterID: corner.fighterId, odds: corner.closingOdds.decimal)
            }
            .frame(maxWidth: .infinity)
            Text("Implied \(FightCoreDisplay.formatImpliedProbability(Money.parse(corner.closingOdds.decimal)))")
                .font(.system(size: DesignTokens.FontSize.caption))
                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
        }
    }

    private var resultPanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Result")
                .font(.system(size: DesignTokens.FontSize.callout, weight: .semibold))
            Text(bout.result.winnerName)
                .foregroundStyle(DesignTokens.ColorToken.positive)
            Text("\(bout.result.method.uppercased()) · \(bout.result.detail)")
            Text("Round \(bout.result.endRound) · \(bout.result.endTime)")
        }
        .font(.system(size: DesignTokens.FontSize.body))
        .foregroundStyle(DesignTokens.ColorToken.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func tapeRow(left: String, label: String, right: String) -> some View {
        HStack {
            Text(left)
                .frame(maxWidth: .infinity)
            Text(label)
                .font(.system(size: DesignTokens.FontSize.caption, weight: .semibold))
                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                .frame(maxWidth: .infinity)
            Text(right)
                .frame(maxWidth: .infinity)
        }
        .font(.system(size: DesignTokens.FontSize.callout))
    }

    private func fighter(_ id: String) -> FighterItem? {
        if case .loaded(let fighters) = state.fightersState {
            return fighters.first { $0.id == id }
        }
        return nil
    }

    private func record(_ id: String) -> String { fighter(id)?.recordDisplay ?? "—" }
    private func height(_ id: String) -> String {
        guard let cm = fighter(id)?.heightCm else { return "—" }
        return "\(cm) cm"
    }
    private func reach(_ id: String) -> String {
        guard let inches = fighter(id)?.reachIn else { return "—" }
        return "\(inches) in"
    }
    private func stance(_ id: String) -> String {
        fighter(id)?.stance?.capitalized ?? "—"
    }
    private func country(_ id: String) -> String { fighter(id)?.country ?? "—" }
}
