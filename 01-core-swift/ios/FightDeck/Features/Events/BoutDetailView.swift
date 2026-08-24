//
// BoutDetailView.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import FightCore
import SwiftUI

struct BoutDetailView: View {
    @Bindable var state: AppState
    let event: EventItem
    let bout: BoutItem
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
                    marketRow(bout.redCorner, ring: DesignTokens.ColorToken.cornerRed)
                    marketRow(bout.blueCorner, ring: DesignTokens.ColorToken.cornerBlue)
                }
            }
            if mode.showsResults {
                Section("Result") {
                    LabeledContent("Winner") {
                        Text(bout.result.winnerName)
                            .foregroundStyle(DesignTokens.ColorToken.positive)
                    }
                    LabeledContent("Method", value: bout.result.method.displayMethod)
                    LabeledContent("Detail", value: bout.result.detail)
                    LabeledContent("Ended", value: "Round \(bout.result.endRound) · \(bout.result.endTime)")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(bout.weightClass.displayMethod)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var matchup: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            cornerColumn(bout.redCorner, ring: DesignTokens.ColorToken.cornerRed)
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
            cornerColumn(bout.blueCorner, ring: DesignTokens.ColorToken.cornerBlue)
        }
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    // A Button rather than a NavigationLink: two links inside one list row make the list draw
    // two disclosure chevrons across the middle of the matchup.
    private func cornerColumn(_ corner: CornerItem, ring: Color) -> some View {
        Button {
            path.append(.fighter(corner.fighterId))
        } label: {
            VStack(spacing: DesignTokens.Spacing.sm) {
                FighterAvatar(
                    url: state.imageURL("assets/fighters/\(corner.fighterId).jpg"),
                    ring: ring,
                    size: 88
                )
                Text(corner.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(state.record(for: corner.fighterId))
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
        Grid(horizontalSpacing: DesignTokens.Spacing.md, verticalSpacing: DesignTokens.Spacing.md) {
            ForEach(tapeRows, id: \.label) { row in
                GridRow {
                    Text(row.red)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.center)
                    Text(row.blue)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.callout)
                // A long country name is worth two lines. Without this the grid hands the
                // cell its one-line ideal width and truncates instead.
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private var tapeRows: [(label: String, red: String, blue: String)] {
        let red = state.fighter(bout.redCorner.fighterId)
        let blue = state.fighter(bout.blueCorner.fighterId)
        return [
            ("RECORD", red?.recordDisplay ?? "—", blue?.recordDisplay ?? "—"),
            ("HEIGHT", format(red?.heightCm, unit: "cm"), format(blue?.heightCm, unit: "cm")),
            ("REACH", format(red?.reachIn, unit: "in"), format(blue?.reachIn, unit: "in")),
            ("STANCE", red?.stance?.localizedCapitalized ?? "—", blue?.stance?.localizedCapitalized ?? "—"),
            ("COUNTRY", red?.country ?? "—", blue?.country ?? "—"),
        ]
    }

    private func format(_ value: Int?, unit: String) -> String {
        guard let value else { return "—" }
        return "\(value) \(unit)"
    }

    /// An `HStack` rather than `LabeledContent`: an avatar plus two lines of text is enough to
    /// tip that layout into stacking, which would drop the odds under the name on some rows
    /// and leave them at the trailing edge on others.
    private func marketRow(_ corner: CornerItem, ring: Color) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            FighterAvatar(
                url: state.imageURL("assets/fighters/\(corner.fighterId).jpg"),
                ring: ring,
                size: 32
            )
            VStack(alignment: .leading) {
                Text(corner.name)
                Text("Implied \(FightCoreDisplay.formatImpliedProbability(Money.parse(corner.closingOdds.decimal)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            OddsButton(
                label: FightCoreDisplay.formatOdds(Money.parse(corner.closingOdds.decimal)),
                fractional: corner.closingOdds.fractional,
                isSelected: state.isSelected(boutID: bout.id, fighterID: corner.fighterId)
            ) {
                state.toggleSelection(bout: bout, fighterID: corner.fighterId, odds: corner.closingOdds.decimal)
            }
        }
    }
}
