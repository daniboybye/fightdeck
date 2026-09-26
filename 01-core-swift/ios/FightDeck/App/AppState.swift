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
    var eventsState: LoadState<[EventSummary]> = .loading
    var newsState: LoadState<[NewsItem]> = .loading
    var mediaState: LoadState<[MediaItem]> = .loading

    var bootstrapState: AppBootstrapState = .loading

    /// Deposit opens from the balance toolbar on every screen. The flag lives here so those
    /// toolbars depend on observable state rather than on a closure handed down through the
    /// environment, which is a new value on every `RootView` body pass.
    var isPresentingDeposit = false

    let catalog: Catalog
    let slipStore: BetSlipStore

    init() {
        // An unreadable dataset shows as empty lists rather than stopping the app at launch.
        self.catalog = (try? Catalog.load(datasetRoot: DatasetLocator.datasetRoot())) ?? .empty
        self.slipStore = BetSlipStore(slipEngine: SlipEngine(bouts: catalog.boutIndex()))
    }

    var slip: BetSlip {
        get { slipStore.slip }
        set { slipStore.slip = newValue }
    }

    var balance: Decimal { slipStore.balance }

    var confirmation: String? { slipStore.confirmation }

    var slipState: SlipState { slipStore.slipState }

    func bootstrap() async {
        bootstrapState = .loading
        do {
            try AssetServer.start(datasetRoot: DatasetLocator.datasetRoot().path)
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
        let events = catalog.eventSummaries()
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

    func toggleSelection(boutID: String, fighterID: String, odds: String) {
        slipStore.toggleSelection(
            boutID: boutID,
            fighterID: fighterID,
            odds: Money.parse(odds)
        )
    }

    func isSelected(boutID: String, fighterID: String) -> Bool {
        slipStore.isSelected(boutID: boutID, fighterID: fighterID)
    }

    func removeSelection(id: String) {
        slipStore.removeSelection(id: id)
    }

    func placeBet() {
        slipStore.placeBet()
    }

    func fighter(_ id: String) -> FighterSummary? {
        catalog.fighterSummary(id: id)
    }

    func bout(_ id: String) -> BoutSummary? {
        catalog.boutSummary(id: id)
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
        AssetServer.url(for: path).flatMap(URL.init(string:))
    }
}
