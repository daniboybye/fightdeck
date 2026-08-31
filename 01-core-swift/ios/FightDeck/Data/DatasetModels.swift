//
// DatasetModels.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

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
    /// Says which public test stream stands in for the licensed footage, so the demo never
    /// passes a cartoon trailer off as a press conference.
    let note: String?
}
