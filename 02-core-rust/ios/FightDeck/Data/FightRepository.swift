//
// FightRepository.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

protocol HostFightRepository {
    func loadNews() async throws -> [NewsItem]
    func loadMedia() async throws -> [MediaItem]
}

enum RepositoryError: Error, Sendable {
    case network(retryable: Bool)
    case decoding(field: String)
}
