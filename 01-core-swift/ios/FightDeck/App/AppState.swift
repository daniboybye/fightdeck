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
    var betPlacedMessage: String?

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
        // The dataset stores image paths relative to the dataset root ("assets/..."), so the
        // server is rooted there. Rooting it at assets/ would strip the prefix and 404.
        try? await LocalAssetServer.shared.start(assetsRoot: DatasetLocator.datasetRoot())
        await refreshAll()
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
        slipStore.toggleSelection(
            boutID: bout.id,
            fighterID: fighterID,
            odds: Money.parse(odds)
        )
        syncMode()
        betPlacedMessage = nil
    }

    func isSelected(boutID: String, fighterID: String) -> Bool {
        slipStore.isSelected(boutID: boutID, fighterID: fighterID)
    }

    func removeSelection(id: String) {
        slipStore.removeSelection(id: id)
        syncMode()
        betPlacedMessage = nil
    }

    func placeBet() {
        let state = slipState
        guard state.errors.isEmpty else { return }
        slipStore.balance -= state.totalStake
        slipStore.slip.selections.removeAll()
        syncMode()
        betPlacedMessage = "\(Money.formatCurrency(state.potentialReturn)) returns if it lands"
    }

    func fighter(_ id: String) -> FighterItem? {
        guard case .loaded(let fighters) = fightersState else { return nil }
        return fighters.first { $0.id == id }
    }

    func record(for id: String) -> String {
        fighter(id)?.recordDisplay ?? "—"
    }

    private func syncMode() {
        slip.mode = slip.selections.count >= FightCore.minAccaLegs ? .accumulator : .single
    }

    func deposit(amount: Decimal) {
        slipStore.deposit(amount: amount)
    }

    func imageURL(_ path: String) -> URL {
        repository.imageURL(for: path)
    }

    private static func makeFightCore() -> FightCore {
        let datasetRoot = DatasetLocator.datasetRoot()
        let url = datasetRoot.appendingPathComponent("events.json")
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(EventsEnvelope.self, from: data) else {
            return FightCore(bouts: [])
        }
        let bouts = file.events.flatMap(\.bouts).map { bout in
            BoutIndex(
                id: bout.id,
                redFighterID: bout.redCorner.fighterId,
                blueFighterID: bout.blueCorner.fighterId,
                winnerID: bout.result.winnerId
            )
        }
        return FightCore(bouts: bouts)
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
