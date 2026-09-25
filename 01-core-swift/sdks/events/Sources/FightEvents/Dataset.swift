//
// Dataset.swift
// FightEvents
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

#if os(Android)
import FoundationEssentials
#else
import Foundation
#endif

public struct EventsFile: Codable, Sendable {
    public let events: [Event]
}

public struct FightersFile: Codable, Sendable {
    public let fighters: [Fighter]
}

public struct Event: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let date: String
    public let venue: String
    public let city: String
    public let bouts: [Bout]
}

public struct Bout: Codable, Identifiable, Sendable {
    public let id: String
    public let order: Int
    public let segment: String
    public let weightClass: String
    public let titleFight: Bool
    public let scheduledRounds: Int
    public let redCorner: Corner
    public let blueCorner: Corner
    public let result: BoutResult
}

public struct Corner: Codable, Sendable {
    public let fighterId: String
    public let name: String
    public let closingOdds: OddsQuote
}

public struct OddsQuote: Codable, Sendable {
    public let decimal: String
    public let fractional: String
}

public struct BoutResult: Codable, Sendable {
    public let winnerId: String
    public let winnerName: String
    public let method: String
    public let detail: String
    public let endRound: Int
    public let endTime: String
}

public struct Fighter: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let nickname: String?
    public let country: String?
    public let heightCm: Int?
    public let reachIn: Int?
    public let stance: String?
    public let record: FighterRecord
    public let portrait: String
}

public struct FighterRecord: Codable, Sendable {
    public let wins: Int
    public let losses: Int
    public let noContests: Int
    public let display: String
}

struct NewsFile: Decodable {
    let news: [NewsItem]
}

struct MediaFile: Decodable {
    let media: [MediaItem]
}

public struct NewsItem: Codable, Identifiable, Sendable {
    public let id: String
    public let eventId: String
    public let headline: String
    public let body: String
    public let publishedAt: String
    public let readMinutes: Int
    public let source: String
    public let heroImage: String
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
}
