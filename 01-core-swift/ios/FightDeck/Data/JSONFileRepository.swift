//
// JSONFileRepository.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightCore
import Foundation

@MainActor
final class JSONFileRepository: FightRepository {
    private let datasetRoot: URL

    init(datasetRoot: URL = DatasetLocator.datasetRoot()) {
        self.datasetRoot = datasetRoot
    }

    func loadEvents() async throws(FightCoreError) -> [EventItem] {
        try await load(file: "events.json", key: "events")
    }

    func loadFighters() async throws(FightCoreError) -> [FighterItem] {
        try await load(file: "fighters.json", key: "fighters")
    }

    func loadNews() async throws(FightCoreError) -> [NewsItem] {
        try await load(file: "news.json", key: "news")
    }

    func loadMedia() async throws(FightCoreError) -> [MediaItem] {
        try await load(file: "media.json", key: "media")
    }

    func imageURL(for relativePath: String) -> URL {
        URL(string: "http://127.0.0.1:\(LocalAssetServer.port)/\(relativePath)")!
    }

    private func load<T: Decodable>(file: String, key: String) async throws(FightCoreError) -> [T] {
        let url = datasetRoot.appendingPathComponent(file)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw FightCoreError.network(retryable: false)
        }
        do {
            let wrapper = try JSONDecoder().decode([String: [T]].self, from: data)
            guard let items = wrapper[key] else {
                throw FightCoreError.decoding(field: key)
            }
            return items
        } catch let error as FightCoreError {
            throw error
        } catch {
            throw FightCoreError.decoding(field: key)
        }
    }
}
