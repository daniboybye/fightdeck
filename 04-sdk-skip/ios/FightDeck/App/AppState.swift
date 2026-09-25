//
// AppState.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import FightDeckEvents
import Foundation
import Observation


enum AppBootstrapState: Equatable {
    case loading
    case failed(String)
    case ready
}

enum LoadState<Value>: Sendable where Value: Sendable {
    case loading
    case loaded(Value)
    case empty
    case error(String)
}

@Observable
@MainActor
final class AppState {
    var eventsState: LoadState<[Event]> = .loading
    var fightersState: LoadState<[Fighter]> = .loading
    var newsState: LoadState<[NewsItem]> = .loading
    var mediaState: LoadState<[MediaItem]> = .loading

    var bootstrapState: AppBootstrapState = .loading

    /// Deposit opens from the balance toolbar on every screen. The flag lives here so those
    /// toolbars depend on observable state rather than on a closure handed down through the
    /// environment, which is a new value on every `RootView` body pass.
    var isPresentingDeposit = false

    let catalog: EventCatalog
    /// The slip, the balance and the bet confirmation. The bet slip SDK reads and writes this
    /// same instance, so there is nothing to copy across in either direction.
    let slipStore: BetSlipStore

    init(datasetRoot: URL = DatasetLocator.datasetRoot()) {
        let catalog = EventCatalog(datasetRoot: datasetRoot)
        self.catalog = catalog
        self.slipStore = BetSlipStore(fightCore: catalog.loadFightCore())
    }

    func bootstrap() async {
        bootstrapState = .loading
        let datasetRoot = DatasetLocator.datasetRoot()
        do {
            try await LocalAssetServer.shared.start(assetsRoot: datasetRoot)
            bootstrapState = .ready
            await refreshAll()
        } catch {
            bootstrapState = .failed("Could not start image server. Check the dataset path.")
        }
    }

    func refreshAll() async {
        await loadEvents()
        await loadFighters()
        await loadNews()
        await loadMedia()
    }

    func loadEvents() async {
        eventsState = .loading
        eventsState = await load("events") { try $0.loadEvents() }
    }

    func loadFighters() async {
        fightersState = .loading
        fightersState = await load("fighters") { try $0.loadFighters() }
    }

    func loadNews() async {
        newsState = .loading
        newsState = await load("news") { try $0.loadNews() }
    }

    func loadMedia() async {
        mediaState = .loading
        mediaState = await load("media") { try $0.loadMedia() }
    }

    /// The shared catalogue is synchronous, so the hop off the main thread is the host's job.
    /// Without it the read and decode would run on the caller's executor and block the UI:
    /// an async function that never suspends never leaves it.
    private func load<T: Sendable>(
        _ label: String,
        _ work: @escaping @Sendable (EventCatalog) throws -> [T]
    ) async -> LoadState<[T]> {
        let catalog = catalog
        do {
            let items = try await Task.detached(priority: .userInitiated) {
                try work(catalog)
            }.value
            return items.isEmpty ? .empty : .loaded(items)
        } catch {
            return .error("Could not load \(label)")
        }
    }

    func presentDeposit() {
        isPresentingDeposit = true
    }

    /// Dataset images are served over localhost, so the URL depends on the port the host's
    /// asset server happened to bind — nothing the shared catalogue can know.
    func imageURL(_ path: String) -> URL? {
        guard LocalAssetServer.port > 0 else { return nil }
        return URL(string: "http://127.0.0.1:\(LocalAssetServer.port)/\(path)")
    }

    func fighter(_ id: String) -> Fighter? {
        guard case .loaded(let fighters) = fightersState else { return nil }
        return fighters.first { $0.id == id }
    }

    func record(for id: String) -> String {
        fighter(id)?.recordDisplay ?? "—"
    }
}
