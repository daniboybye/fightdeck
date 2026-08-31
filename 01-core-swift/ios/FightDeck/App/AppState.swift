//
// AppState.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightCore
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
    var betPlacedMessage: String?

    /// Deposit opens from the balance toolbar on every screen. The flag lives here so those
    /// toolbars depend on observable state rather than on a closure handed down through the
    /// environment, which is a new value on every `RootView` body pass.
    var isPresentingDeposit = false

    let repository: JSONFileRepository
    let slipStore: BetSlipStore

    init(repository: JSONFileRepository = JSONFileRepository()) {
        self.repository = repository
        let core = AppState.makeFightCore()
        self.slipStore = BetSlipStore(
            fightCore: core,
            slip: BetSlip(mode: .single, selections: [], stake: Decimal(string: "10.00")!)
        )
    }

    var slip: BetSlip {
        get { slipStore.slip }
        set { slipStore.slip = newValue }
    }

    var balance: Decimal {
        get { slipStore.balance }
        set { slipStore.balance = newValue }
    }

    var slipState: SlipState { slipStore.slipState }

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

    func retryBootstrap() async {
        await bootstrap()
    }

    func refreshAll() async {
        await loadEvents()
        await loadFighters()
        await loadNews()
        await loadMedia()
    }

    func loadEvents() async {
        eventsState = .loading
        do {
            let events = try await repository.loadEvents()
            eventsState = events.isEmpty ? .empty : .loaded(events)
        } catch {
            eventsState = .error("Could not load events")
        }
    }

    func loadFighters() async {
        fightersState = .loading
        do {
            let fighters = try await repository.loadFighters()
            fightersState = fighters.isEmpty ? .empty : .loaded(fighters)
        } catch {
            fightersState = .error("Could not load fighters")
        }
    }

    func loadNews() async {
        newsState = .loading
        do {
            let news = try await repository.loadNews()
            newsState = news.isEmpty ? .empty : .loaded(news)
        } catch {
            newsState = .error("Could not load news")
        }
    }

    func loadMedia() async {
        mediaState = .loading
        do {
            let media = try await repository.loadMedia()
            mediaState = media.isEmpty ? .empty : .loaded(media)
        } catch {
            mediaState = .error("Could not load media")
        }
    }

    func toggleSelection(bout: Bout, fighterID: String, odds: String) {
        slipStore.toggleSelection(
            boutID: bout.id,
            fighterID: fighterID,
            odds: Money.parse(odds)
        )
        betPlacedMessage = nil
    }

    func isSelected(boutID: String, fighterID: String) -> Bool {
        slipStore.isSelected(boutID: boutID, fighterID: fighterID)
    }

    func removeSelection(id: String) {
        slipStore.removeSelection(id: id)
        betPlacedMessage = nil
    }

    func removeSelection(boutID: String, fighterID: String) {
        slipStore.removeSelection(boutID: boutID, fighterID: fighterID)
        betPlacedMessage = nil
    }

    func placeBet() {
        guard let state = slipStore.placeBet() else { return }
        betPlacedMessage = "\(Money.formatCurrency(state.potentialReturn)) returns if it lands"
    }

    func fighter(_ id: String) -> Fighter? {
        guard case .loaded(let fighters) = fightersState else { return nil }
        return fighters.first { $0.id == id }
    }

    func record(for id: String) -> String {
        fighter(id)?.recordDisplay ?? "—"
    }

    func presentDeposit() {
        isPresentingDeposit = true
    }

    func deposit(amount: Decimal) {
        slipStore.deposit(amount: amount)
    }

    func imageURL(_ path: String) -> URL? {
        repository.imageURL(for: path)
    }

    private static func makeFightCore() -> FightCore {
        let datasetRoot = DatasetLocator.datasetRoot()
        let url = datasetRoot.appendingPathComponent("events.json")
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(EventsEnvelope.self, from: data) else {
            return FightCore(bouts: [])
        }
        return FightCore.make(from: file.events)
    }
}

private struct EventsEnvelope: Decodable {
    let events: [Event]
}
