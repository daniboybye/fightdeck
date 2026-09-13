//
// BoutDetailView.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightEvents
import SwiftUI

struct BoutDetailView: View {
    @Bindable var state: AppState
    let event: EventSummary
    let bout: BoutSummary
    @Binding var path: [EventsRoute]
    let mode: EventMode

    var body: some View {
        List {
            Section {
                matchup
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section("Tale of the tape") {
                taleOfTheTape
            }
            if mode.showsOdds {
                Section("Outright winner") {
                    marketRow(bout.red, ring: DesignTokens.ColorToken.cornerRed)
                    marketRow(bout.blue, ring: DesignTokens.ColorToken.cornerBlue)
                }
            }
            if mode.showsResults {
                Section("Result") {
                    LabeledContent("Winner") {
                        Text(bout.winnerName)
                            .foregroundStyle(DesignTokens.ColorToken.positive)
                    }
                    LabeledContent("Method", value: bout.resultMethod.displayMethod)
                    LabeledContent("Detail", value: bout.resultDetail)
                    LabeledContent("Ended", value: "Round \(bout.endRound) · \(bout.endTime)")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(bout.weightClassDisplay)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var matchup: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            cornerColumn(bout.red, ring: DesignTokens.ColorToken.cornerRed)
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("VS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                if bout.titleFight {
                    Image(systemName: "medal.fill")
                        .foregroundStyle(DesignTokens.ColorToken.accent)
                }
            }
            .padding(.top, DesignTokens.Spacing.xl)
            cornerColumn(bout.blue, ring: DesignTokens.ColorToken.cornerBlue)
        }
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    // A Button rather than a NavigationLink: two links inside one list row make the list draw
    // two disclosure chevrons across the middle of the matchup.
    private func cornerColumn(_ corner: CornerSummary, ring: Color) -> some View {
        Button {
            path.append(.fighter(corner.fighterId))
        } label: {
            VStack(spacing: DesignTokens.Spacing.sm) {
                FighterAvatar(
                    url: state.imageURL(corner.portraitPath),
                    ring: ring,
                    size: 88
                )
                Text(corner.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(corner.recordDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    /// The outer columns take the leftover width so the values sit on the row's edges. A bare
    /// `Grid` sizes every column to its widest cell and centres the whole block, which leaves
    /// both fighters floating in the middle of the card.
    private var taleOfTheTape: some View {
        let tape = try? state.catalog.taleOfTheTape(boutId: bout.id)
        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Grid(horizontalSpacing: DesignTokens.Spacing.md, verticalSpacing: DesignTokens.Spacing.md) {
                ForEach(tape?.rows ?? [], id: \.label) { row in
                    GridRow {
                        Text(row.red)
                            .fontWeight(row.advantage == .red ? .semibold : .regular)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(row.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(.center)
                        Text(row.blue)
                            .fontWeight(row.advantage == .blue ? .semibold : .regular)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.callout)
                    // A long country name is worth two lines. Without this the grid hands the
                    // cell its one-line ideal width and truncates instead.
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let edge = tape?.edgeSummary {
                Text(edge)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    /// An `HStack` rather than `LabeledContent`: an avatar plus two lines of text is enough to
    /// tip that layout into stacking, which would drop the odds under the name on some rows
    /// and leave them at the trailing edge on others.
    private func marketRow(_ corner: CornerSummary, ring: Color) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            FighterAvatar(
                url: state.imageURL(corner.portraitPath),
                ring: ring,
                size: 32
            )
            VStack(alignment: .leading) {
                Text(corner.name)
                Text("Implied \(corner.impliedProbability)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            OddsButton(
                label: FightCoreDisplay.formatOdds(corner.oddsDecimal),
                fractional: corner.oddsFractional,
                isSelected: state.isSelected(boutID: bout.id, fighterID: corner.fighterId)
            ) {
                state.toggleSelection(bout: bout, fighterID: corner.fighterId, odds: corner.oddsDecimal)
            }
        }
    }
}
