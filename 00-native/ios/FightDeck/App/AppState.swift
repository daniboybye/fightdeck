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

    /// The mode follows the number of legs rather than a picker: one selection is a single,
    /// two or more is an accumulator.
    var slip = BetSlip(mode: .single, selections: [], stake: .init(string: "10.00")!)
    var balance = Decimal(string: "500.00")!
    var betPlacedMessage: String?

    /// The balance toolbar on every screen opens deposit. The flag lives here so those
    /// toolbars observe state instead of a closure that is new on every `RootView` body pass.
    var isPresentingDeposit = false

    let repository: JSONFileRepository
    let fightCore: FightCore

    init(repository: JSONFileRepository = JSONFileRepository()) {
        self.repository = repository
        self.fightCore = AppState.makeFightCore()
    }

    var slipState: SlipState {
        fightCore.slipState(slip: slip, balance: balance)
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
        eventsState = await load("events", repository.loadEvents)
    }

    func loadFighters() async {
        fightersState = .loading
        fightersState = await load("fighters", repository.loadFighters)
    }

    func loadNews() async {
        newsState = .loading
        newsState = await load("news", repository.loadNews)
    }

    func loadMedia() async {
        mediaState = .loading
        mediaState = await load("media", repository.loadMedia)
    }

    private func load<Value: Sendable>(
        _ subject: String,
        _ fetch: () async throws -> [Value]
    ) async -> LoadState<[Value]> {
        do {
            let items = try await fetch()
            return items.isEmpty ? .empty : .loaded(items)
        } catch {
            return .error("Could not load \(subject)")
        }
    }

    func toggleSelection(bout: BoutItem, fighterID: String, odds: String) {
        if let index = slip.selections.firstIndex(where: { $0.boutID == bout.id }) {
            let existing = slip.selections[index]
            if existing.fighterID == fighterID {
                slip.selections.remove(at: index)
            } else {
                slip.selections[index] = .init(
                    boutID: bout.id,
                    fighterID: fighterID,
                    odds: Money.parse(odds)
                )
            }
        } else {
            slip.selections.append(
                .init(boutID: bout.id, fighterID: fighterID, odds: Money.parse(odds))
            )
        }
        syncMode()
        betPlacedMessage = nil
    }

    func isSelected(boutID: String, fighterID: String) -> Bool {
        slip.selections.contains { $0.boutID == boutID && $0.fighterID == fighterID }
    }

    func removeSelection(id: String) {
        slip.selections.removeAll { $0.id == id }
        syncMode()
        betPlacedMessage = nil
    }

    func placeBet() {
        let state = slipState
        guard state.errors.isEmpty else { return }
        balance -= state.totalStake
        slip.selections.removeAll()
        syncMode()
        betPlacedMessage = "\(Money.formatCurrency(state.potentialReturn)) returns if it lands"
    }

    private func syncMode() {
        slip.mode = slip.selections.count >= FightCore.minAccaLegs ? .accumulator : .single
    }

    func presentDeposit() {
        isPresentingDeposit = true
    }

    func deposit(amount: Decimal) {
        balance += amount
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

    private static func makeFightCore() -> FightCore {
        let datasetRoot = DatasetLocator.datasetRoot()
        let url = datasetRoot.appendingPathComponent("events.json")
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(EventsEnvelope.self, from: data) else {
            return .init(bouts: [])
        }
        let bouts: [BoutIndex] = file.events.flatMap(\.bouts).map { bout in
            .init(
                id: bout.id,
                redFighterID: bout.redCorner.fighterId,
                blueFighterID: bout.blueCorner.fighterId,
                winnerID: bout.result.winnerId
            )
        }
        return .init(bouts: bouts)
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
