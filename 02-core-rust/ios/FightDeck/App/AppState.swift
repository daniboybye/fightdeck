//
// AppState.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

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
    var eventsState: LoadState<[EventItem]> = .loading
    var fightersState: LoadState<[FighterItem]> = .loading
    var newsState: LoadState<[NewsItem]> = .loading
    var mediaState: LoadState<[MediaItem]> = .loading

    var bootstrapState: AppBootstrapState = .loading

    let slipStore: ObservableBetSlipStore
    let core: FightCoreHandle
    let preferences: UserDefaultsPreferencesStore

    var betPlacedMessage: String?

    /// Deposit opens from the balance toolbar on every screen. The flag lives here so those
    /// toolbars depend on observable state rather than on a closure handed down through the
    /// environment, which is a new value on every `RootView` body pass.
    var isPresentingDeposit = false

    private let repository: JSONFileRepository

    init(repository: JSONFileRepository = JSONFileRepository()) {
        self.repository = repository
        self.preferences = UserDefaultsPreferencesStore()
        self.core = AppState.makeCore()
        let store = try! BetSlipStore(core: core, balance: "500.00")
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

    func toggleSelection(bout: BoutItem, fighterID: String, odds: String) {
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
        guard let state = slipStore.placeBet() else { return }
        betPlacedMessage = "\(FightCoreDisplay.formatCurrencyAmount(state.potentialReturn)) returns if it lands"
    }

    func presentDeposit() {
        isPresentingDeposit = true
    }

    func deposit(amount: Decimal) {
        let raw = NSDecimalNumber(decimal: amount).stringValue
        guard let formatted = try? formatMoney(amount: raw) else { return }
        try? slipStore.deposit(amount: formatted)
    }

    func imageURL(_ path: String) -> URL? {
        repository.imageURL(for: path)
    }

    func fighter(_ id: String) -> FighterItem? {
        guard case .loaded(let fighters) = fightersState else { return nil }
        return fighters.first { $0.id == id }
    }

    func record(for id: String) -> String {
        fighter(id)?.recordDisplay ?? "—"
    }

    private static func makeCore() -> FightCoreHandle {
        let url = DatasetLocator.datasetRoot().appendingPathComponent("events.json")
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(EventsEnvelope.self, from: data) else {
            return FightCoreHandle(bouts: [])
        }
        let bouts = file.events.flatMap(\.bouts).map { bout in
            BoutIndexRecord(
                id: bout.id,
                redFighterId: bout.redCorner.fighterId,
                blueFighterId: bout.blueCorner.fighterId,
                winnerId: bout.result.winnerId
            )
        }
        return FightCoreHandle(bouts: bouts)
    }
}

private struct EventsEnvelope: Decodable {
    let events: [EventEnvelope]
}

private struct EventEnvelope: Decodable {
    let bouts: [BoutEnvelope]
}

private struct BoutEnvelope: Decodable {
    let id: String
    let redCorner: CornerEnvelope
    let blueCorner: CornerEnvelope
    let result: ResultEnvelope
}

private struct CornerEnvelope: Decodable {
    let fighterId: String
}

private struct ResultEnvelope: Decodable {
    let winnerId: String
}

extension ValidationErrorRecord: Identifiable {
    public var id: String { validationErrorCode(error: self) }
}

extension ValidationErrorRecord {
    var displayName: String { validationErrorCode(error: self) }
}
