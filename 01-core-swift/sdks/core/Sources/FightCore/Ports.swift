//
// Ports.swift
// FightCore
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import Foundation

public struct Event: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let date: String
    public let venue: String
    public let city: String
    public let bouts: [Bout]

    public init(id: String, name: String, date: String, venue: String, city: String, bouts: [Bout]) {
        self.id = id
        self.name = name
        self.date = date
        self.venue = venue
        self.city = city
        self.bouts = bouts
    }
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

    public init(
        id: String,
        order: Int,
        segment: String,
        weightClass: String,
        titleFight: Bool,
        scheduledRounds: Int,
        redCorner: Corner,
        blueCorner: Corner,
        result: BoutResult
    ) {
        self.id = id
        self.order = order
        self.segment = segment
        self.weightClass = weightClass
        self.titleFight = titleFight
        self.scheduledRounds = scheduledRounds
        self.redCorner = redCorner
        self.blueCorner = blueCorner
        self.result = result
    }
}

public struct Corner: Codable, Sendable {
    public let fighterId: String
    public let name: String
    public let closingOdds: OddsQuote

    public init(fighterId: String, name: String, closingOdds: OddsQuote) {
        self.fighterId = fighterId
        self.name = name
        self.closingOdds = closingOdds
    }
}

public struct OddsQuote: Codable, Sendable {
    public let decimal: String
    public let fractional: String

    public init(decimal: String, fractional: String) {
        self.decimal = decimal
        self.fractional = fractional
    }
}

public struct BoutResult: Codable, Sendable {
    public let winnerId: String
    public let winnerName: String
    public let method: String
    public let detail: String
    public let endRound: Int
    public let endTime: String

    public init(
        winnerId: String,
        winnerName: String,
        method: String,
        detail: String,
        endRound: Int,
        endTime: String
    ) {
        self.winnerId = winnerId
        self.winnerName = winnerName
        self.method = method
        self.detail = detail
        self.endRound = endRound
        self.endTime = endTime
    }
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

    public var recordDisplay: String { record.display }

    public init(
        id: String,
        name: String,
        nickname: String?,
        country: String?,
        heightCm: Int?,
        reachIn: Int?,
        stance: String?,
        record: FighterRecord,
        portrait: String
    ) {
        self.id = id
        self.name = name
        self.nickname = nickname
        self.country = country
        self.heightCm = heightCm
        self.reachIn = reachIn
        self.stance = stance
        self.record = record
        self.portrait = portrait
    }
}

public struct FighterRecord: Codable, Sendable {
    public let wins: Int
    public let losses: Int
    public let draws: Int
    public let noContests: Int
    public let display: String

    public init(wins: Int, losses: Int, draws: Int, noContests: Int, display: String) {
        self.wins = wins
        self.losses = losses
        self.draws = draws
        self.noContests = noContests
        self.display = display
    }
}

/// Platform port — implemented by the host (UserDefaults on iOS, SharedPreferences on Android).
public protocol PreferencesStore: Sendable {
    func read(key: String) -> String?
    func write(key: String, value: String)
}

/// Platform port — host supplies the current time.
public protocol Clock: Sendable {
    func now() -> Date
}

/// Platform port — async data loading with typed errors across the FFI boundary.
public protocol FightRepository: Sendable {
    func loadEvents() async throws(FightCoreError) -> [Event]
    func loadFighters() async throws(FightCoreError) -> [Fighter]
}

public extension FightCore {
    static func make(from events: [Event]) -> FightCore {
        let bouts = events.flatMap(\.bouts).map { bout in
            BoutIndex(
                id: bout.id,
                redFighterID: bout.redCorner.fighterId,
                blueFighterID: bout.blueCorner.fighterId,
                winnerID: bout.result.winnerId
            )
        }
        return FightCore(bouts: bouts)
    }
}
