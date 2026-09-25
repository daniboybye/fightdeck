//
// AppState.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

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

    let slipStore: ObservableBetSlipStore

    /// FightEvents loads the dataset and hands FightSlip its bout index. The two feature SDKs
    /// never reference each other — the app is the only place they meet.
    let catalog: EventCatalog

    var betPlacedMessage: String?

    /// Deposit opens from the balance toolbar on every screen. The flag lives here so those
    /// toolbars depend on observable state rather than on a closure handed down through the
    /// environment, which is a new value on every `RootView` body pass.
    var isPresentingDeposit = false

    init() {
        // An unreadable dataset shows as empty lists rather than stopping the app at launch.
        self.catalog = (try? EventCatalog.load(datasetRoot: DatasetLocator.datasetRoot().path))
            ?? EventCatalog.empty()
        let handle = SlipHandle(bouts: catalog.boutIndex().map(BoutIndexRecord.init))
        let store = try! BetSlipStore(handle: handle, balance: "500.00")
        self.slipStore = ObservableBetSlipStore(store: store)
    }

    var slip: BetSlipRecord { slipStore.snapshot.slip }

    var slipState: SlipStateRecord { slipStore.snapshot.state }

    func bootstrap() async {
        bootstrapState = .loading
        do {
            _ = try startAssetServer(datasetRoot: DatasetLocator.datasetRoot().path)
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
        let events = catalog.events()
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

    func toggleSelection(bout: BoutSummary, fighterID: String, odds: String) {
        slipStore.toggleSelection(boutId: bout.id, fighterId: fighterID, odds: odds)
        betPlacedMessage = nil
    }

    func isSelected(boutID: String, fighterID: String) -> Bool {
        slipStore.isSelected(boutId: boutID, fighterId: fighterID)
    }

    func removeSelection(boutID: String, fighterID: String) {
        slipStore.removeSelection(boutId: boutID, fighterId: fighterID)
        betPlacedMessage = nil
    }

    func placeBet() {
        betPlacedMessage = slipStore.placeBet().message
    }

    func presentDeposit() {
        isPresentingDeposit = true
    }

    func deposit(amount: String) {
        slipStore.deposit(amount: amount)
    }

    func imageURL(_ path: String) -> URL? {
        assetUrl(path: path).flatMap(URL.init(string:))
    }

    func fighter(_ id: String) -> FighterSummary? {
        try? catalog.fighter(id: id)
    }
}

private extension BoutIndexRecord {
    /// FightEvents produces the index, FightSlip consumes it. Independent SDKs mean
    /// independent types, and the app pays four lines for that independence.
    init(_ entry: BoutIndexEntry) {
        self.init(
            id: entry.id,
            redFighterId: entry.redFighterId,
            blueFighterId: entry.blueFighterId,
            winnerId: entry.winnerId
        )
    }
}

// Retroactive because the records are the SDKs' and Identifiable is the standard library's.
// UniFFI will not emit the conformance, so the app has to own it and accept that a future
// version of an SDK could add its own.
extension EventSummary: @retroactive Identifiable {}

extension BoutSummary: @retroactive Identifiable {}

extension FighterSummary: @retroactive Identifiable {}

extension NewsItem: @retroactive Identifiable {}

extension MediaItem: @retroactive Identifiable {}

