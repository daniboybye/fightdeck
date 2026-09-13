//
// JSONFileRepository.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

final class JSONFileRepository: @unchecked Sendable {
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
        return try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: url)
            let wrapper = try JSONDecoder().decode([String: [T]].self, from: data)
            guard let items = wrapper[key] else {
                throw RepositoryError.decoding(field: key)
            }
            return items
        }.value
    }
}

enum RepositoryError: Error, Sendable {
    case decoding(field: String)
}
