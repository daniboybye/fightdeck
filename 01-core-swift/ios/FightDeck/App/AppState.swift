//
// AppState.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightCore
import FightEvents
import FightSlip
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
    var newsState: LoadState<[NewsItem]> = .loading
    var mediaState: LoadState<[MediaItem]> = .loading

    var bootstrapState: AppBootstrapState = .loading
    var betPlacedMessage: String?

    /// Deposit opens from the balance toolbar on every screen. The flag lives here so those
    /// toolbars depend on observable state rather than on a closure handed down through the
    /// environment, which is a new value on every `RootView` body pass.
    var isPresentingDeposit = false

    let catalog: Catalog
    let slipStore: BetSlipStore

    private let repository: JSONFileRepository

    init(repository: JSONFileRepository = JSONFileRepository()) {
        self.repository = repository
        self.catalog = AppState.makeCatalog()
        let slipEngine = SlipEngine(bouts: catalog.boutIndex())
        self.slipStore = BetSlipStore(
            slipEngine: slipEngine,
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

    func refreshAll() async {
        loadEvents()
        await loadNews()
        await loadMedia()
    }

    func loadEvents() {
        eventsState = .loading
        let events = catalog.allEvents()
        eventsState = events.isEmpty ? .empty : .loaded(events)
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
        catalog.fighter(id: id)
    }

    func record(for id: String) -> String {
        fighter(id)?.recordDisplay ?? "—"
    }

    func cardSections(for eventID: String) -> [CardSection] {
        catalog.cardSections(eventID: eventID)
    }

    func taleOfTheTape(for boutID: String) -> TaleOfTheTape? {
        catalog.taleOfTheTape(boutID: boutID)
    }

    func legContext(boutID: String, fighterID: String) -> LegContext {
        catalog.legContext(boutID: boutID, fighterID: fighterID)
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

    /// The dataset is read as text and parsed inside FightEvents, so the app declares no
    /// `Codable` mirror of the JSON and neither does the Android host.
    private static func makeCatalog() -> Catalog {
        let root = DatasetLocator.datasetRoot()
        func read(_ name: String, empty: String) -> String {
            (try? String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)) ?? empty
        }
        let events = read("events.json", empty: #"{"events":[]}"#)
        let fighters = read("fighters.json", empty: #"{"fighters":[]}"#)
        return (try? Catalog.parse(eventsJSON: events, fightersJSON: fighters))
            ?? (try! Catalog.parse(eventsJSON: #"{"events":[]}"#, fightersJSON: #"{"fighters":[]}"#))
    }
}
