//
// Catalog.swift
// FightEvents
//
// Created by FightDeck on 13.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightCore
#if os(Android)
import FoundationEssentials
#else
import Foundation
#endif

public enum CatalogError: Error, Sendable {
    case decoding(field: String)
    case unreadable(file: String)
}

public struct CardSection: Sendable {
    public let title: String
    public let bouts: [Bout]
}

public struct LegContext: Sendable {
    public let fighterName: String
    public let subtitle: String
}

public struct Catalog: Sendable {
    private let events: [Event]
    private let fighters: [String: Fighter]
    /// Every lookup by bout goes through here; a bout row alone asks for its bout a dozen times.
    private let bouts: [String: Bout]
    private let boutToEvent: [String: String]
    private var loadedNews: Result<[NewsItem], any Error> = .success([])
    private var loadedMedia: Result<[MediaItem], any Error> = .success([])

    /// What the app shows when there is no dataset to load.
    public static let empty = Catalog(events: [], fighters: [:], bouts: [:], boutToEvent: [:])

    /// The host still decides where the dataset lives — the app bundle, a scheme variable, a
    /// folder pushed over adb — and hands over the directory. Reading and parsing it is ours.
    public static func load(datasetRoot: URL) throws -> Catalog {
        func read(_ name: String) throws -> Data {
            do {
                return try Data(contentsOf: datasetRoot.appendingPathComponent(name))
            } catch {
                throw CatalogError.unreadable(file: name)
            }
        }
        var catalog = try parse(eventsData: read("events.json"), fightersData: read("fighters.json"))
        // A broken news or media file costs its own section, not the whole catalogue.
        catalog.loadedNews = Result {
            try decode(NewsFile.self, from: read("news.json"), field: "news").news
        }
        catalog.loadedMedia = Result {
            try decode(MediaFile.self, from: read("media.json"), field: "media").media
        }
        return catalog
    }

    private static func parse(eventsData: Data, fightersData: Data) throws -> Catalog {
        let eventsFile = try decode(EventsFile.self, from: eventsData, field: "events")
        let fightersFile = try decode(FightersFile.self, from: fightersData, field: "fighters")

        var bouts: [String: Bout] = [:]
        var boutToEvent: [String: String] = [:]
        for event in eventsFile.events {
            for bout in event.bouts {
                bouts[bout.id] = bout
                boutToEvent[bout.id] = event.id
            }
        }

        let fighters = Dictionary(uniqueKeysWithValues: fightersFile.fighters.map { ($0.id, $0) })
        return Catalog(events: eventsFile.events, fighters: fighters, bouts: bouts, boutToEvent: boutToEvent)
    }

    private init(events: [Event], fighters: [String: Fighter], bouts: [String: Bout], boutToEvent: [String: String]) {
        self.events = events
        self.fighters = fighters
        self.bouts = bouts
        self.boutToEvent = boutToEvent
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data, field: String) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw CatalogError.decoding(field: field)
        }
    }

    public func allEvents() -> [Event] {
        events
    }

    public func news() throws -> [NewsItem] {
        try loadedNews.get()
    }

    public func media() throws -> [MediaItem] {
        try loadedMedia.get()
    }

    public func event(id: String) -> Event? {
        events.first { $0.id == id }
    }

    public func fighter(id: String) -> Fighter? {
        fighters[id]
    }

    public func bout(id: String) -> Bout? {
        bouts[id]
    }

    public func eventOfBout(boutID: String) -> Event? {
        guard let eventID = boutToEvent[boutID] else { return nil }
        return event(id: eventID)
    }

    public func boutIndex() -> [BoutIndex] {
        events.flatMap(\.bouts).map { bout in
            BoutIndex(
                id: bout.id,
                redFighterID: bout.redCorner.fighterId,
                blueFighterID: bout.blueCorner.fighterId,
                winnerID: bout.result.winnerId
            )
        }
    }

    public func cardSections(eventID: String) -> [CardSection] {
        guard let event = event(id: eventID) else { return [] }
        var grouped: [String: [Bout]] = [:]
        for bout in event.bouts {
            grouped[bout.segment, default: []].append(bout)
        }
        let segments = grouped.keys.sorted { Display.segmentRank($0) < Display.segmentRank($1) }
        return segments.compactMap { segment in
            guard var bouts = grouped[segment], !bouts.isEmpty else { return nil }
            bouts.sort { $0.order < $1.order }
            return CardSection(title: Display.segmentTitle(segment), bouts: bouts)
        }
    }

    public func opponentOf(boutID: String, fighterID: String) -> Fighter? {
        guard let bout = bout(id: boutID) else { return nil }
        let opponentID = bout.redCorner.fighterId == fighterID
            ? bout.blueCorner.fighterId
            : bout.redCorner.fighterId
        return fighter(id: opponentID)
    }

    public func taleOfTheTape(boutID: String) -> TaleOfTheTape? {
        guard let bout = bout(id: boutID) else { return nil }
        let red = fighter(id: bout.redCorner.fighterId)
        let blue = fighter(id: bout.blueCorner.fighterId)
        return Tape.taleOfTheTape(red: red, blue: blue)
    }

    public func legContext(boutID: String, fighterID: String) -> LegContext {
        let fighterName = fighter(id: fighterID)?.name ?? fighterID
        let opponentName = opponentOf(boutID: boutID, fighterID: fighterID)?.name ?? "—"
        let eventName = eventOfBout(boutID: boutID)?.name ?? "—"
        return LegContext(fighterName: fighterName, subtitle: "vs \(opponentName) · \(eventName)")
    }
}
