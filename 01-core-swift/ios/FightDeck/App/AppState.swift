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

    init() {
        // An unreadable dataset shows as empty lists rather than stopping the app at launch.
        self.catalog = (try? Catalog.load(datasetRoot: DatasetLocator.datasetRoot())) ?? .empty
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
        loadNews()
        loadMedia()
    }

    func loadEvents() {
        eventsState = .loading
        let events = catalog.allEvents()
        eventsState = events.isEmpty ? .empty : .loaded(events)
    }

    func loadNews() {
        guard let news = try? catalog.news() else {
            newsState = .error("Could not load news")
            return
        }
        newsState = news.isEmpty ? .empty : .loaded(news)
    }

    func loadMedia() {
        guard let media = try? catalog.media() else {
            mediaState = .error("Could not load media")
            return
        }
        mediaState = media.isEmpty ? .empty : .loaded(media)
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
        guard LocalAssetServer.port > 0 else { return nil }
        return URL(string: "http://127.0.0.1:\(LocalAssetServer.port)/\(path)")
    }
}
