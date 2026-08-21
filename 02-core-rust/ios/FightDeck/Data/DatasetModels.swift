//
// DatasetModels.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import Foundation

struct EventItem: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let date: String
    let venue: String
    let city: String
    let bouts: [BoutItem]
}

struct BoutItem: Codable, Identifiable, Sendable {
    let id: String
    let order: Int
    let segment: String
    let weightClass: String
    let titleFight: Bool
    let scheduledRounds: Int
    let redCorner: CornerItem
    let blueCorner: CornerItem
    let result: BoutResultItem
}

struct CornerItem: Codable, Sendable {
    let fighterId: String
    let name: String
    let closingOdds: OddsItem
}

struct OddsItem: Codable, Sendable {
    let decimal: String
    let fractional: String
}

struct BoutResultItem: Codable, Sendable {
    let winnerId: String
    let winnerName: String
    let method: String
    let detail: String
    let endRound: Int
    let endTime: String
}

struct FighterItem: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let nickname: String?
    let country: String?
    let heightCm: Int?
    let reachIn: Int?
    let stance: String?
    let record: FighterRecordStats
    let portrait: String

    var recordDisplay: String { record.display }
}

struct FighterRecordStats: Codable, Sendable {
    let wins: Int
    let losses: Int
    let draws: Int
    let noContests: Int
    let display: String
}

struct NewsItem: Codable, Identifiable, Sendable {
    let id: String
    let eventId: String
    let headline: String
    let body: String
    let publishedAt: String
    let readMinutes: Int
    let source: String
    let heroImage: String
}

struct MediaItem: Codable, Identifiable, Sendable {
    let id: String
    let eventId: String
    let title: String
    let kind: String
    let url: String
    let poster: String
    let durationSeconds: Int
}
