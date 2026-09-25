//
// AppState.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import FightDeckEvents
import Foundation
import Observation


enum AppBootstrapState: Equatable {
    case loading
    case failed(String)
    case ready
}

@Observable
@MainActor
final class AppState {
    var bootstrapState: AppBootstrapState = .loading

    /// Deposit opens from the balance toolbar on every screen. The flag lives here so those
    /// toolbars depend on observable state rather than on a closure handed down through the
    /// environment, which is a new value on every `RootView` body pass.
    var isPresentingDeposit = false

    /// Events, fighters, news and media with their load states — the same model the Android
    /// host holds.
    let catalog: CatalogModel
    /// The slip, the balance and the bet confirmation. The bet slip SDK reads and writes this
    /// same instance, so there is nothing to copy across in either direction.
    let slipStore: BetSlipStore

    init(datasetRoot: URL = DatasetLocator.datasetRoot()) {
        let catalog = EventCatalog(datasetRoot: datasetRoot)
        self.catalog = CatalogModel(catalog: catalog)
        self.slipStore = BetSlipStore(fightCore: catalog.loadFightCore())
    }

    func bootstrap() async {
        bootstrapState = .loading
        do {
            _ = try AssetServer.shared.start(datasetRoot: DatasetLocator.datasetRoot().path)
            bootstrapState = .ready
            await catalog.loadAll()
        } catch {
            bootstrapState = .failed("Could not start image server. Check the dataset path.")
        }
    }

    func presentDeposit() {
        isPresentingDeposit = true
    }

    func imageURL(_ path: String) -> URL? {
        AssetServer.shared.url(for: path).flatMap(URL.init(string:))
    }
}
