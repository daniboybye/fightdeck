//
// JSONFileRepository.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

final class JSONFileRepository: HostFightRepository, @unchecked Sendable {
    private let datasetRoot: URL

    init(datasetRoot: URL = DatasetLocator.datasetRoot()) {
        self.datasetRoot = datasetRoot
    }

    func loadNews() async throws -> [NewsItem] {
        try await load(file: "news.json", key: "news")
    }

    func loadMedia() async throws -> [MediaItem] {
        try await load(file: "media.json", key: "media")
    }

    func imageURL(for relativePath: String) -> URL? {
        guard LocalAssetServer.port > 0 else { return nil }
        return URL(string: "http://127.0.0.1:\(LocalAssetServer.port)/\(relativePath)")
    }

    private func load<T: Decodable & Sendable>(file: String, key: String) async throws -> [T] {
        let url = datasetRoot.appendingPathComponent(file)
        // Every caller is main-actor isolated, and an async function that never suspends runs
        // on the caller's executor — so without this hop the read and decode block the UI.
        return try await Task.detached(priority: .userInitiated) {
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
        }.value
    }
}
