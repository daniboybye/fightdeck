//
// CatalogModel.swift
// FightDeckEvents
//
// Created by FightDeck on 25.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import Foundation
import Observation

/// Where one list of the catalogue stands. Every screen has all four (spec rule 5), and both
/// hosts used to declare this type for themselves — a Swift enum and a Kotlin sealed interface
/// with the same four cases. `@frozen` because the xcframework is built for library evolution,
/// and the four states are the whole set: without it every host `switch` needs an
/// `@unknown default`.
@frozen
public enum CatalogLoad<Value> {
    case loading
    case loaded(Value)
    case empty
    case error(String)
}

/// The catalogue as the screens see it: the four lists, each with its load state, and the two
/// lookups the event screens make into the roster. Both hosts hold one and read it directly —
/// skipstone backs `@Observable` properties with Compose state, so a composable that reads
/// `catalog.events` recomposes when the list arrives, as a SwiftUI view does.
///
/// The work of reading happens off the main thread in here, which is the one idiom the hosts
/// used to write twice (`Task.detached` on iOS, `withContext(Dispatchers.IO)` on Android).
/// Navigation, and everything drawn from these lists, stays in the hosts.
@Observable
@MainActor
public final class CatalogModel {
    public private(set) var events: CatalogLoad<[Event]> = CatalogLoad.loading
    public private(set) var fighters: CatalogLoad<[Fighter]> = CatalogLoad.loading
    public private(set) var news: CatalogLoad<[NewsItem]> = CatalogLoad.loading
    public private(set) var media: CatalogLoad<[MediaItem]> = CatalogLoad.loading

    private let catalog: EventCatalog

    public init(catalog: EventCatalog) {
        self.catalog = catalog
    }

    public func loadAll() async {
        await loadEvents()
        await loadFighters()
        await loadNews()
        await loadMedia()
    }

    public func loadEvents() async {
        events = CatalogLoad.loading
        let catalog = catalog
        events = await load("events") { try catalog.loadEvents() }
    }

    public func loadFighters() async {
        fighters = CatalogLoad.loading
        let catalog = catalog
        fighters = await load("fighters") { try catalog.loadFighters() }
    }

    public func loadNews() async {
        news = CatalogLoad.loading
        let catalog = catalog
        news = await load("news") { try catalog.loadNews() }
    }

    public func loadMedia() async {
        media = CatalogLoad.loading
        let catalog = catalog
        media = await load("media") { try catalog.loadMedia() }
    }

    /// The loaded events, or none while they load or failed to.
    public var loadedEvents: [Event] {
        if case .loaded(let events) = events { return events }
        return []
    }

    /// The loaded roster, or none while it loads or failed to.
    public var loadedFighters: [Fighter] {
        if case .loaded(let fighters) = fighters { return fighters }
        return []
    }

    public var loadedNews: [NewsItem] {
        if case .loaded(let news) = news { return news }
        return []
    }

    public var loadedMedia: [MediaItem] {
        if case .loaded(let media) = media { return media }
        return []
    }

    public func fighter(_ id: String) -> Fighter? {
        loadedFighters.first { $0.id == id }
    }

    /// "17-0-0", or a dash until the roster has loaded.
    public func record(for fighterID: String) -> String {
        fighter(fighterID)?.recordDisplay ?? "—"
    }

    /// The catalogue is synchronous, so leaving the main thread is this model's job. Without the
    /// detached task the read and decode would run on the caller's executor and block the UI:
    /// an async function that never suspends never leaves it.
    private func load<T: Sendable>(
        _ label: String,
        _ work: @escaping @Sendable () throws -> [T]
    ) async -> CatalogLoad<[T]> {
        do {
            let items = try await Task.detached(priority: .userInitiated) {
                try work()
            }.value
            return items.isEmpty ? CatalogLoad.empty : CatalogLoad.loaded(items)
        } catch {
            return CatalogLoad.error("Could not load \(label)")
        }
    }
}
