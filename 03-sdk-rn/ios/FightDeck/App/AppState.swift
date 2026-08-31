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

    /// The mode follows the number of legs instead of a picker: one selection is a single,
    /// two or more is an accumulator. Both modes stay covered by the golden fixtures.
    var slip = BetSlip(mode: .single, selections: [], stake: Decimal(string: "10.00")!)
    var balance = Decimal(string: "500.00")!
    var betPlacedMessage: String?

    /// Deposit opens from the balance toolbar on every screen. The flag lives here so those
    /// toolbars depend on observable state rather than on a closure handed down through the
    /// environment, which is a new value on every `RootView` body pass.
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
        if let index = slip.selections.firstIndex(where: { $0.boutID == bout.id }) {
            let existing = slip.selections[index]
            if existing.fighterID == fighterID {
                slip.selections.remove(at: index)
            } else {
                slip.selections[index] = Selection(
                    boutID: bout.id,
                    fighterID: fighterID,
                    odds: Money.parse(odds)
                )
            }
        } else {
            slip.selections.append(
                Selection(boutID: bout.id, fighterID: fighterID, odds: Money.parse(odds))
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

    func applySlipJSON(_ json: String) {
        guard let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(SlipPayload.self, from: data) else {
            return
        }
        slip = payload.toBetSlip()
        syncMode()
        betPlacedMessage = nil
    }

    func placeBetFromSDK(message: String, slipJSON: String, balanceString: String) {
        applySlipJSON(slipJSON)
        balance = Money.parse(balanceString)
        betPlacedMessage = message
    }

    func presentDeposit() {
        isPresentingDeposit = true
    }

    func deposit(amount: Decimal) {
        balance += amount
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

struct SlipPayload: Codable {
    let mode: BetMode
    let stake: String
    let selections: [SelectionPayload]

    init(from slip: BetSlip) {
        mode = slip.mode
        stake = Money.format(slip.stake)
        selections = slip.selections.map(SelectionPayload.init)
    }

    func toBetSlip() -> BetSlip {
        BetSlip(
            mode: mode,
            selections: selections.map { $0.toSelection() },
            stake: Money.parse(stake)
        )
    }
}

struct SelectionPayload: Codable {
    let boutId: String
    let fighterId: String
    let odds: String

    init(from selection: Selection) {
        boutId = selection.boutID
        fighterId = selection.fighterID
        odds = Money.format(selection.odds)
    }

    func toSelection() -> Selection {
        Selection(boutID: boutId, fighterID: fighterId, odds: Money.parse(odds))
    }
}
