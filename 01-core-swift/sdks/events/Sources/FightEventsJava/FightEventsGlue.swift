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

// Every read returns a labelled tuple, for the reasons the slip glue gives: one JNI call fills
// it, it arrives as plain Java values, and no Swift instance is left for the collector. The
// values are the presentation models iOS reads (`BoutSummary`, `FighterSummary`, …), flattened.
// A list of records crosses as parallel arrays of equal length — jextract 0.6.0 skips an array
// of tuples — and a bout's two corners as arrays of two, red first.

struct NotFound: Error {
    let id: String
}

/// Android-facing handle over `Catalog`. The host finds the dataset directory; reading and
/// parsing it happens on this side.
public final class EventCatalogBridge {
    private let catalog: Catalog

    public init(datasetRoot: String) throws {
        catalog = try Catalog.load(datasetRoot: URL(fileURLWithPath: datasetRoot, isDirectory: true))
    }

    public func events() -> (
        ids: [String],
        names: [String],
        dates: [String],
        locations: [String],
        boutCounts: [Int],
        posters: [String]
    ) {
        let events = catalog.eventSummaries()
        return (
            ids: events.map(\.id),
            names: events.map(\.name),
            dates: events.map(\.date),
            locations: events.map(\.locationLine),
            boutCounts: events.map(\.boutCount),
            posters: events.map(\.posterPath)
        )
    }

    /// Section titles, and the bout ids under each in card order; `bout(id:)` has the rest.
    public func cardSections(eventID: String) -> (titles: [String], boutIDs: [[String]]) {
        let sections = catalog.cardSections(eventID: eventID)
        return (titles: sections.map(\.title), boutIDs: sections.map { $0.bouts.map(\.id) })
    }

    public func bout(id: String) throws -> (
        id: String,
        headline: String,
        weightClass: String,
        titleFight: Bool,
        resultLine: String,
        winnerName: String,
        method: String,
        detail: String,
        ended: String,
        fighterIDs: [String],
        names: [String],
        records: [String],
        portraits: [String],
        odds: [String],
        oddsLabels: [String]
    ) {
        guard let bout = catalog.boutSummary(id: id) else { throw NotFound(id: id) }
        let corners = [bout.red, bout.blue]
        return (
            id: bout.id,
            headline: bout.headline,
            weightClass: bout.weightClassDisplay,
            titleFight: bout.titleFight,
            resultLine: bout.resultLine,
            winnerName: bout.winnerName,
            method: bout.methodDisplay,
            detail: bout.detail,
            ended: bout.endedLine,
            fighterIDs: corners.map(\.fighterID),
            names: corners.map(\.name),
            records: corners.map(\.recordDisplay),
            portraits: corners.map(\.portraitPath),
            odds: corners.map(\.odds),
            oddsLabels: corners.map(\.oddsLabel)
        )
    }

    public func fighter(id: String) throws -> (
        id: String,
        name: String,
        nickname: String?,
        record: String,
        portrait: String,
        profileLabels: [String],
        profileValues: [String],
        physicalLabels: [String],
        physicalValues: [String]
    ) {
        guard let fighter = catalog.fighterSummary(id: id) else { throw NotFound(id: id) }
        return (
            id: fighter.id,
            name: fighter.name,
            nickname: fighter.nickname,
            record: fighter.recordDisplay,
            portrait: fighter.portraitPath,
            profileLabels: fighter.profileRows.map(\.label),
            profileValues: fighter.profileRows.map(\.value),
            physicalLabels: fighter.physicalRows.map(\.label),
            physicalValues: fighter.physicalRows.map(\.value)
        )
    }

    public func taleOfTheTape(boutID: String) -> (labels: [String], red: [String], blue: [String]) {
        let rows = (catalog.taleOfTheTape(boutID: boutID) ?? Tape.taleOfTheTape(red: nil, blue: nil)).rows
        return (labels: rows.map(\.label), red: rows.map(\.red), blue: rows.map(\.blue))
    }

    public func legContext(boutID: String, fighterID: String) -> (fighterName: String, subtitle: String) {
        let context = catalog.legContext(boutID: boutID, fighterID: fighterID)
        return (fighterName: context.fighterName, subtitle: context.subtitle)
    }

    /// Handed straight to the slip glue's `SlipEngine`, which decodes it on its own side.
    public var boutIndexJSON: String {
        let data = (try? JSONEncoder().encode(catalog.boutIndex())) ?? Data("[]".utf8)
        return String(decoding: data, as: UTF8.self)
    }

    public func news() throws -> (
        ids: [String],
        eventIDs: [String],
        headlines: [String],
        bodies: [String],
        readMinutes: [Int],
        sources: [String],
        heroImages: [String]
    ) {
        let news = try catalog.news()
        return (
            ids: news.map(\.id),
            eventIDs: news.map(\.eventId),
            headlines: news.map(\.headline),
            bodies: news.map(\.body),
            readMinutes: news.map(\.readMinutes),
            sources: news.map(\.source),
            heroImages: news.map(\.heroImage)
        )
    }

    /// `notes` is empty where the dataset has none.
    public func media() throws -> (
        ids: [String],
        eventIDs: [String],
        titles: [String],
        kinds: [String],
        urls: [String],
        posters: [String],
        durations: [String],
        notes: [String]
    ) {
        let media = try catalog.media()
        return (
            ids: media.map(\.id),
            eventIDs: media.map(\.eventId),
            titles: media.map(\.title),
            kinds: media.map(\.kind),
            urls: media.map(\.url),
            posters: media.map(\.poster),
            durations: media.map { Display.duration(totalSeconds: $0.durationSeconds) },
            notes: media.map { $0.note ?? "" }
        )
    }
}
