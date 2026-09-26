//
// Presentation.swift
// FightEvents
//
// Created by FightDeck on 26.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightCore
#if os(Android)
import FoundationEssentials
#else
import Foundation
#endif

// What the event screens show, worded and formatted once. SwiftUI reads these directly; the
// Android glue flattens the same values for Kotlin, so both hosts reach a label by one path
// instead of each composing it from the dataset.

public struct EventSummary: Identifiable, Sendable {
    public let id: String
    public let name: String
    /// `yyyy-MM-dd`, as the dataset writes it. Showing a date in the device's locale is the
    /// host's job: on Android the Swift side would have to bring its own ICU to do it.
    public let date: String
    /// `Etihad Arena · Abu Dhabi`.
    public let locationLine: String
    public let boutCount: Int
    public let posterPath: String
}

public struct CornerSummary: Sendable {
    public let fighterID: String
    public let name: String
    public let recordDisplay: String
    public let portraitPath: String
    /// The closing price as the dataset writes it: what a tap captures on the slip.
    public let odds: String
    /// Two places, whatever the dataset wrote, so no odds button formats its own label.
    public let oddsLabel: String
    public let oddsFractional: String
    public let impliedProbability: String
}

public struct BoutSummary: Identifiable, Sendable {
    public let id: String
    public let headline: String
    public let weightClassDisplay: String
    public let titleFight: Bool
    public let red: CornerSummary
    public let blue: CornerSummary
    public let resultLine: String
    public let winnerName: String
    public let methodDisplay: String
    public let detail: String
    /// `Round 5 · 5:00`.
    public let endedLine: String
}

public struct CardSection: Sendable {
    public let title: String
    public let bouts: [BoutSummary]
}

public struct ProfileRow: Sendable, Hashable {
    public let label: String
    public let value: String
}

public struct FighterSummary: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let nickname: String?
    public let recordDisplay: String
    public let portraitPath: String
    public let profileRows: [ProfileRow]
    /// Only what the dataset has: several fighters publish no reach or stance, and a row
    /// that says so would be noise.
    public let physicalRows: [ProfileRow]
}

extension Catalog {
    public func eventSummaries() -> [EventSummary] {
        allEvents().map { event in
            EventSummary(
                id: event.id,
                name: event.name,
                date: event.date,
                locationLine: "\(event.venue) · \(event.city)",
                boutCount: event.bouts.count,
                posterPath: "assets/events/\(event.id).jpg"
            )
        }
    }

    public func boutSummary(id: String) -> BoutSummary? {
        bout(id: id).map(summary)
    }

    public func cardSections(eventID: String) -> [CardSection] {
        guard let event = event(id: eventID) else { return [] }
        var grouped: [String: [Bout]] = [:]
        for bout in event.bouts {
            grouped[bout.segment, default: []].append(bout)
        }
        let segments = grouped.keys.sorted { Display.segmentRank($0) < Display.segmentRank($1) }
        return segments.compactMap { segment in
            guard let bouts = grouped[segment], !bouts.isEmpty else { return nil }
            return CardSection(
                title: Display.segmentTitle(segment),
                bouts: bouts.sorted { $0.order < $1.order }.map(summary)
            )
        }
    }

    public func fighterSummary(id: String) -> FighterSummary? {
        guard let fighter = fighter(id: id) else { return nil }
        var profile = [
            ProfileRow(label: "Record", value: fighter.record.display),
            ProfileRow(label: "Wins", value: "\(fighter.record.wins)"),
            ProfileRow(label: "Losses", value: "\(fighter.record.losses)"),
        ]
        if fighter.record.noContests > 0 {
            profile.append(ProfileRow(label: "No contests", value: "\(fighter.record.noContests)"))
        }
        let physicals: [ProfileRow] = [
            fighter.heightCm.map { ProfileRow(label: "Height", value: "\($0) cm") },
            fighter.reachIn.map { ProfileRow(label: "Reach", value: "\($0) in") },
            fighter.stance.map { ProfileRow(label: "Stance", value: Display.humanise($0)) },
            fighter.country.map { ProfileRow(label: "Country", value: $0) },
        ].compactMap { $0 }
        return FighterSummary(
            id: fighter.id,
            name: fighter.name,
            nickname: fighter.nickname,
            recordDisplay: fighter.record.display,
            portraitPath: fighter.portrait,
            profileRows: profile,
            physicalRows: physicals
        )
    }

    private func summary(_ bout: Bout) -> BoutSummary {
        BoutSummary(
            id: bout.id,
            headline: Display.boutHeadline(
                weightClassRaw: bout.weightClass,
                titleFight: bout.titleFight,
                scheduledRounds: bout.scheduledRounds
            ),
            weightClassDisplay: Display.weightClass(bout.weightClass),
            titleFight: bout.titleFight,
            red: summary(bout.redCorner),
            blue: summary(bout.blueCorner),
            resultLine: Display.resultLine(
                winnerName: bout.result.winnerName,
                method: bout.result.method,
                endRound: bout.result.endRound,
                endTime: bout.result.endTime
            ),
            winnerName: bout.result.winnerName,
            methodDisplay: Display.humanise(bout.result.method),
            detail: bout.result.detail,
            endedLine: "Round \(bout.result.endRound) · \(bout.result.endTime)"
        )
    }

    private func summary(_ corner: Corner) -> CornerSummary {
        let odds = Money.parse(corner.closingOdds.decimal)
        return CornerSummary(
            fighterID: corner.fighterId,
            name: corner.name,
            recordDisplay: fighter(id: corner.fighterId)?.record.display ?? "—",
            portraitPath: fighter(id: corner.fighterId)?.portrait ?? "assets/fighters/\(corner.fighterId).jpg",
            odds: corner.closingOdds.decimal,
            oddsLabel: Money.formatOdds(odds),
            oddsFractional: corner.closingOdds.fractional,
            impliedProbability: Money.formatImpliedProbability(odds)
        )
    }
}
