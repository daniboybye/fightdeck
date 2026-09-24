//
// FightEventsGlue.swift
// FightEventsJava
//
// Created by FightDeck on 13.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightCore
import FightEvents
#if os(Android)
import FoundationEssentials
#else
import Foundation
#endif

public func humaniseCode(_ raw: String) -> String {
    Display.humanise(raw)
}

public func formatDuration(totalSeconds: Int) -> String {
    Display.duration(totalSeconds: totalSeconds)
}

public func segmentTitle(_ segment: String) -> String {
    Display.segmentTitle(segment)
}

public final class TapeRowBridge {
    public let label: String
    public let red: String
    public let blue: String
    public let advantage: String

    init(_ row: TapeRow) {
        label = row.label
        red = row.red
        blue = row.blue
        advantage = row.advantage.rawValue
    }
}

public final class TaleOfTheTapeBridge {
    public let rows: [TapeRowBridge]
    public let edgeSummary: String

    init(_ tape: TaleOfTheTape) {
        rows = tape.rows.map(TapeRowBridge.init)
        edgeSummary = tape.edgeSummary ?? ""
    }
}

public final class BoutIndexEntryBridge {
    public let id: String
    public let redFighterID: String
    public let blueFighterID: String
    public let winnerID: String

    init(_ entry: BoutIndex) {
        id = entry.id
        redFighterID = entry.redFighterID
        blueFighterID = entry.blueFighterID
        winnerID = entry.winnerID
    }
}

public final class LegContextBridge {
    public let fighterName: String
    public let opponentName: String
    public let eventName: String
    public let subtitle: String

    init(_ context: LegContext) {
        fighterName = context.fighterName
        opponentName = context.opponentName
        eventName = context.eventName
        subtitle = context.subtitle
    }
}

/// Android-facing handle over `Catalog`. The host reads JSON files and hands the text in;
/// the SDK does no file I/O.
public final class EventCatalogBridge {
    private let catalog: Catalog

    public init(eventsJSON: String, fightersJSON: String) throws {
        catalog = try Catalog.parse(eventsJSON: eventsJSON, fightersJSON: fightersJSON)
    }

    public var eventCount: Int { catalog.allEvents().count }

    public func eventID(at index: Int) -> String {
        catalog.allEvents()[index].id
    }

    public func eventName(id: String) -> String {
        catalog.event(id: id)?.name ?? ""
    }

    public func eventDate(id: String) -> String {
        catalog.event(id: id)?.date ?? ""
    }

    public func eventVenue(id: String) -> String {
        catalog.event(id: id)?.venue ?? ""
    }

    public func eventCity(id: String) -> String {
        catalog.event(id: id)?.city ?? ""
    }

    public func eventBoutCount(id: String) -> Int {
        catalog.event(id: id)?.bouts.count ?? 0
    }

    public func cardSectionCount(eventID: String) -> Int {
        catalog.cardSections(eventID: eventID).count
    }

    public func cardSectionTitle(eventID: String, sectionIndex: Int) -> String {
        catalog.cardSections(eventID: eventID)[sectionIndex].title
    }

    public func cardSectionBoutCount(eventID: String, sectionIndex: Int) -> Int {
        catalog.cardSections(eventID: eventID)[sectionIndex].bouts.count
    }

    public func cardSectionBoutID(eventID: String, sectionIndex: Int, boutIndex: Int) -> String {
        catalog.cardSections(eventID: eventID)[sectionIndex].bouts[boutIndex].id
    }

    public func boutEventID(boutID: String) -> String {
        catalog.eventOfBout(boutID: boutID)?.id ?? ""
    }

    public func boutHeadline(boutID: String) -> String {
        guard let bout = catalog.bout(id: boutID) else { return "" }
        return Display.boutHeadline(
            weightClassRaw: bout.weightClass,
            titleFight: bout.titleFight,
            scheduledRounds: bout.scheduledRounds
        )
    }

    public func boutWeightClassDisplay(boutID: String) -> String {
        guard let bout = catalog.bout(id: boutID) else { return "" }
        return Display.weightClass(bout.weightClass)
    }

    public func boutTitleFight(boutID: String) -> Bool {
        catalog.bout(id: boutID)?.titleFight ?? false
    }

    public func cornerFighterID(boutID: String, isRed: Bool) -> String {
        guard let bout = catalog.bout(id: boutID) else { return "" }
        return isRed ? bout.redCorner.fighterId : bout.blueCorner.fighterId
    }

    public func cornerName(boutID: String, isRed: Bool) -> String {
        guard let bout = catalog.bout(id: boutID) else { return "" }
        return isRed ? bout.redCorner.name : bout.blueCorner.name
    }

    public func cornerOddsDecimal(boutID: String, isRed: Bool) -> String {
        guard let bout = catalog.bout(id: boutID) else { return "" }
        return isRed ? bout.redCorner.closingOdds.decimal : bout.blueCorner.closingOdds.decimal
    }

    public func cornerRecordDisplay(boutID: String, isRed: Bool) -> String {
        guard let bout = catalog.bout(id: boutID) else { return "—" }
        let fighterID = isRed ? bout.redCorner.fighterId : bout.blueCorner.fighterId
        return catalog.fighter(id: fighterID)?.record.display ?? "—"
    }

    public func boutResultLine(boutID: String) -> String {
        guard let bout = catalog.bout(id: boutID) else { return "" }
        return Display.resultLine(
            winnerName: bout.result.winnerName,
            method: bout.result.method,
            endRound: bout.result.endRound,
            endTime: bout.result.endTime
        )
    }

    public func boutWinnerName(boutID: String) -> String {
        catalog.bout(id: boutID)?.result.winnerName ?? ""
    }

    public func boutResultMethod(boutID: String) -> String {
        catalog.bout(id: boutID)?.result.method ?? ""
    }

    public func boutResultDetail(boutID: String) -> String {
        catalog.bout(id: boutID)?.result.detail ?? ""
    }

    public func boutEndRound(boutID: String) -> Int {
        catalog.bout(id: boutID)?.result.endRound ?? 0
    }

    public func boutEndTime(boutID: String) -> String {
        catalog.bout(id: boutID)?.result.endTime ?? ""
    }

    public func fighterName(id: String) -> String {
        catalog.fighter(id: id)?.name ?? id
    }

    public func fighterNickname(id: String) -> String {
        catalog.fighter(id: id)?.nickname ?? ""
    }

    public func fighterCountry(id: String) -> String {
        catalog.fighter(id: id)?.country ?? ""
    }

    public func fighterRecordDisplay(id: String) -> String {
        catalog.fighter(id: id)?.record.display ?? "—"
    }

    public func fighterWins(id: String) -> Int {
        catalog.fighter(id: id)?.record.wins ?? 0
    }

    public func fighterLosses(id: String) -> Int {
        catalog.fighter(id: id)?.record.losses ?? 0
    }

    public func fighterNoContests(id: String) -> Int {
        catalog.fighter(id: id)?.record.noContests ?? 0
    }

    // The three measurements are optional in the dataset and jextract carries no optionals, so
    // they cross already formatted, with an empty string standing for absent — the same
    // convention `fighterNickname` and `fighterCountry` already use.
    public func fighterHeightDisplay(id: String) -> String {
        catalog.fighter(id: id)?.heightCm.map { "\($0) cm" } ?? ""
    }

    public func fighterReachDisplay(id: String) -> String {
        catalog.fighter(id: id)?.reachIn.map { "\($0) in" } ?? ""
    }

    // `Display.humanise`, not `localizedCapitalized`: the Android build links
    // FoundationEssentials precisely to keep ICU out, and the locale-aware casing lives on the
    // other side of that line.
    public func fighterStanceDisplay(id: String) -> String {
        catalog.fighter(id: id)?.stance.map(Display.humanise) ?? ""
    }

    public func fighterPortraitPath(id: String) -> String {
        catalog.fighter(id: id)?.portrait ?? "assets/fighters/\(id).jpg"
    }

    public func taleOfTheTape(boutID: String) -> TaleOfTheTapeBridge {
        let tape = catalog.taleOfTheTape(boutID: boutID)
            ?? TaleOfTheTape(rows: Tape.rows(red: nil, blue: nil), edgeSummary: nil)
        return TaleOfTheTapeBridge(tape)
    }

    public func legContext(boutID: String, fighterID: String) -> LegContextBridge {
        LegContextBridge(catalog.legContext(boutID: boutID, fighterID: fighterID))
    }

    public var boutIndexEntries: [BoutIndexEntryBridge] {
        catalog.boutIndex().map(BoutIndexEntryBridge.init)
    }
}
