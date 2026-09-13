//
// Catalog.swift
// FightDeckEvents
//
// Created by FightDeck on 13.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import Foundation

public struct NewsItem: Codable, Identifiable, Sendable {
    public let id: String
    public let eventId: String
    public let headline: String
    public let body: String
    public let publishedAt: String
    public let readMinutes: Int
    public let source: String
    public let heroImage: String

    public init(
        id: String,
        eventId: String,
        headline: String,
        body: String,
        publishedAt: String,
        readMinutes: Int,
        source: String,
        heroImage: String
    ) {
        self.id = id
        self.eventId = eventId
        self.headline = headline
        self.body = body
        self.publishedAt = publishedAt
        self.readMinutes = readMinutes
        self.source = source
        self.heroImage = heroImage
    }
}

public struct MediaItem: Codable, Identifiable, Sendable {
    public let id: String
    public let eventId: String
    public let title: String
    public let kind: String
    public let url: String
    public let poster: String
    public let durationSeconds: Int
    /// Says which public test stream stands in for the licensed footage, so the demo never
    /// passes a cartoon trailer off as a press conference.
    public let note: String?

    public init(
        id: String,
        eventId: String,
        title: String,
        kind: String,
        url: String,
        poster: String,
        durationSeconds: Int,
        note: String?
    ) {
        self.id = id
        self.eventId = eventId
        self.title = title
        self.kind = kind
        self.url = url
        self.poster = poster
        self.durationSeconds = durationSeconds
        self.note = note
    }
}

/// Reads the JSON dataset both apps ship and hands back the catalogue they render.
///
/// Every method is synchronous on purpose. The two hosts have different ways of leaving the
/// main thread — `Task.detached` on iOS, `withContext(Dispatchers.IO)` on Android — and a
/// shared `async` API would force one of them to adopt the other's idiom for no gain.
public struct EventCatalog: Sendable {
    private let datasetRoot: URL

    public init(datasetRoot: URL) {
        self.datasetRoot = datasetRoot
    }

    // One function per file rather than one generic `load<T: Decodable>`: Kotlin needs a reified
    // type parameter to pick a deserialiser, and a transpiled Swift generic cannot supply one —
    // `Cannot use 'T' as reified type parameter` is what skipstone's Kotlin output hits.
    public func loadEvents() throws -> [Event] {
        let data = try read("events.json")
        do {
            return try JSONDecoder().decode(EventsFile.self, from: data).events
        } catch {
            throw FightCoreError.decoding(field: "events")
        }
    }

    public func loadFighters() throws -> [Fighter] {
        let data = try read("fighters.json")
        do {
            return try JSONDecoder().decode(FightersFile.self, from: data).fighters
        } catch {
            throw FightCoreError.decoding(field: "fighters")
        }
    }

    public func loadNews() throws -> [NewsItem] {
        let data = try read("news.json")
        do {
            return try JSONDecoder().decode(NewsFile.self, from: data).news
        } catch {
            throw FightCoreError.decoding(field: "news")
        }
    }

    public func loadMedia() throws -> [MediaItem] {
        let data = try read("media.json")
        do {
            return try JSONDecoder().decode(MediaFile.self, from: data).media
        } catch {
            throw FightCoreError.decoding(field: "media")
        }
    }

    /// The bout index the betting core needs. Both hosts used to parse `events.json` a second
    /// time through their own envelope structs to build this.
    public func loadFightCore() -> FightCore {
        guard let events = try? loadEvents() else { return FightCore(bouts: []) }
        return FightCore.make(from: events)
    }

    private func read(_ file: String) throws -> Data {
        do {
            return try Data(contentsOf: datasetRoot.appendingPathComponent(file))
        } catch {
            throw FightCoreError.network(retryable: false)
        }
    }
}

/// The dataset wraps every collection in a single-key object. Decoding through named structs
/// rather than `[String: [T]]` keeps the failure a typed `decoding(field:)` instead of a
/// missing-key check at the call site.
private struct EventsFile: Decodable {
    let events: [Event]
}

private struct FightersFile: Decodable {
    let fighters: [Fighter]
}

private struct NewsFile: Decodable {
    let news: [NewsItem]
}

private struct MediaFile: Decodable {
    let media: [MediaItem]
}
