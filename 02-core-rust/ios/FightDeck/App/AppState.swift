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

    let slipStore: ObservableBetSlipStore

    /// FightEvents parses the dataset and hands FightSlip its bout index. The two feature SDKs
    /// never reference each other — the app is the only place they meet.
    let catalog: EventCatalog

    var betPlacedMessage: String?

    /// Deposit opens from the balance toolbar on every screen. The flag lives here so those
    /// toolbars depend on observable state rather than on a closure handed down through the
    /// environment, which is a new value on every `RootView` body pass.
    var isPresentingDeposit = false

    private let repository: JSONFileRepository

    init(repository: JSONFileRepository = JSONFileRepository()) {
        self.repository = repository
        self.catalog = AppState.makeCatalog()
        let handle = SlipHandle(bouts: catalog.boutIndex().map(BoutIndexRecord.init))
        let store = try! BetSlipStore(handle: handle, balance: "500.00")
        self.slipStore = ObservableBetSlipStore(store: store)
    }

    var slipState: SlipStateRecord { slipStore.slipState }

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
        loadEvents()
        await loadNews()
        await loadMedia()
    }

    func loadEvents() {
        eventsState = .loading
        let events = catalog.events()
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

    func deposit(amount: Decimal) {
        let raw = NSDecimalNumber(decimal: amount).stringValue
        guard let formatted = try? formatMoney(amount: raw) else { return }
        slipStore.deposit(amount: formatted)
    }

    func imageURL(_ path: String) -> URL? {
        repository.imageURL(for: path)
    }

    func fighter(_ id: String) -> FighterSummary? {
        try? catalog.fighter(id: id)
    }

    /// The dataset is read as text and parsed inside FightEvents, so the app declares no
    /// `Codable` mirror of the JSON and neither does the Android host.
    private static func makeCatalog() -> EventCatalog {
        let root = DatasetLocator.datasetRoot()
        func read(_ name: String, empty: String) -> String {
            (try? String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)) ?? empty
        }
        let events = read("events.json", empty: #"{"events":[]}"#)
        let fighters = read("fighters.json", empty: #"{"fighters":[]}"#)
        return (try? EventCatalog.parse(eventsJson: events, fightersJson: fighters))
            ?? (try! EventCatalog.parse(eventsJson: #"{"events":[]}"#, fightersJson: #"{"fighters":[]}"#))
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

extension EventSummary: Identifiable {}

extension BoutSummary: Identifiable {}

extension FighterSummary: Identifiable {}

// Retroactive because the record is FightSlip's and Identifiable is the standard library's.
// UniFFI will not emit the conformance, so the app has to own it and accept that a future
// version of the SDK could add its own.
extension ValidationErrorRecord: @retroactive Identifiable {
    public var id: String { validationErrorCode(error: self) }
}

extension ValidationErrorRecord {
    var displayName: String { validationErrorCode(error: self) }
}
