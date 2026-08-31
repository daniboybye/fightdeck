//
// JSONFileRepository.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightCore
import Foundation

final class JSONFileRepository: FightRepository, @unchecked Sendable {
    private let datasetRoot: URL

    init(datasetRoot: URL = DatasetLocator.datasetRoot()) {
        self.datasetRoot = datasetRoot
    }

    func loadEvents() async throws(FightCoreError) -> [Event] {
        try await load(file: "events.json", key: "events")
    }

    func loadFighters() async throws(FightCoreError) -> [Fighter] {
        try await load(file: "fighters.json", key: "fighters")
    }

    func loadNews() async throws(FightCoreError) -> [NewsItem] {
        try await load(file: "news.json", key: "news")
    }

    func loadMedia() async throws(FightCoreError) -> [MediaItem] {
        try await load(file: "media.json", key: "media")
    }

    func imageURL(for relativePath: String) -> URL? {
        guard LocalAssetServer.port > 0 else { return nil }
        return URL(string: "http://127.0.0.1:\(LocalAssetServer.port)/\(relativePath)")
    }

    private func load<T: Decodable & Sendable>(file: String, key: String) async throws(FightCoreError) -> [T] {
        let url = datasetRoot.appendingPathComponent(file)
        // Every caller is main-actor isolated, and an async function that never suspends runs
        // on the caller's executor — so without this hop the read and decode block the UI.
        // The Result round-trip keeps the typed throw a detached task cannot carry.
        let outcome = await Task.detached(priority: .userInitiated) { () -> Result<[T], FightCoreError> in
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                return .failure(FightCoreError.network(retryable: false))
            }
            do {
                let wrapper = try JSONDecoder().decode([String: [T]].self, from: data)
                guard let items = wrapper[key] else {
                    return .failure(FightCoreError.decoding(field: key))
                }
                return .success(items)
            } catch {
                return .failure(FightCoreError.decoding(field: key))
            }
        }.value
        switch outcome {
        case .success(let items):
            return items
        case .failure(let error):
            throw error
        }
    }
}
