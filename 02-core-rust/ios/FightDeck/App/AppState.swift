//
// AppState.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

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

    let slipStore: ObservableBetSlipStore
    let core: FightCoreHandle
    let preferences: UserDefaultsPreferencesStore

    var betPlacedMessage: String?
    var simulateNetworkFailure = false

    private let repository: JSONFileRepository

    init(repository: JSONFileRepository = JSONFileRepository()) {
        self.repository = repository
        self.preferences = UserDefaultsPreferencesStore()
        self.core = AppState.makeCore()
        let store = BetSlipStore(core: core, balance: "500.00")
        self.slipStore = ObservableBetSlipStore(store: store)
    }

    var slipState: SlipStateRecord { slipStore.slipState }

    func bootstrap() async {
        let datasetRoot = DatasetLocator.datasetRoot()
        // The dataset stores image paths relative to the dataset root ("assets/..."), so the
        // server is rooted there. Rooting it at assets/ would strip the prefix and 404.
        try? await LocalAssetServer.shared.start(assetsRoot: datasetRoot)
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
        repository.shouldFail = simulateNetworkFailure
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
        betPlacedMessage = "Bet placed · \(FightCoreDisplay.formatCurrencyAmount(state.potentialReturn)) to return"
    }

    func deposit(amount: Decimal) {
        slipStore.deposit(amount: formatMoney(amount: NSDecimalNumber(decimal: amount).stringValue))
    }

    func imageURL(_ path: String) -> URL {
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
    public var id: String { String(describing: self) }
}

extension ValidationErrorRecord {
    var displayName: String {
        switch self {
        case .emptySlip: return "empty_slip"
        case .stakeBelowMinimum: return "stake_below_minimum"
        case .stakeAboveMaximum: return "stake_above_maximum"
        case .insufficientBalance: return "insufficient_balance"
        case .tooManySelections: return "too_many_selections"
        case .accumulatorNeedsTwoLegs: return "accumulator_needs_two_legs"
        case .duplicateBout: return "duplicate_bout"
        case .unknownBout: return "unknown_bout"
        case .fighterNotInBout: return "fighter_not_in_bout"
        case .payoutExceedsLimit: return "payout_exceeds_limit"
        }
    }
}
