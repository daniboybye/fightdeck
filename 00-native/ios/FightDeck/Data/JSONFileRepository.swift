//
// JSONFileRepository.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import Foundation

@MainActor
final class JSONFileRepository: FightRepository {
    private let datasetRoot: URL

    init(datasetRoot: URL = DatasetLocator.datasetRoot()) {
        self.datasetRoot = datasetRoot
    }

    func loadEvents() async throws -> [EventItem] {
        try await load(file: "events.json", key: "events")
    }

    func loadFighters() async throws -> [FighterItem] {
        try await load(file: "fighters.json", key: "fighters")
    }

    func loadNews() async throws -> [NewsItem] {
        try await load(file: "news.json", key: "news")
    }

    func loadMedia() async throws -> [MediaItem] {
        try await load(file: "media.json", key: "media")
    }

    func imageURL(for relativePath: String) -> URL {
        URL(string: "http://127.0.0.1:\(LocalAssetServer.port)/\(relativePath)")!
    }

    private func load<T: Decodable>(file: String, key: String) async throws -> [T] {
        let url = datasetRoot.appendingPathComponent(file)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw RepositoryError.network(retryable: false)
        }
        do {
            let wrapper = try JSONDecoder().decode([String: [T]].self, from: data)
            guard let items = wrapper[key] else {
                throw RepositoryError.decoding(field: key)
            }
            return items
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.decoding(field: key)
        }
    }
}
