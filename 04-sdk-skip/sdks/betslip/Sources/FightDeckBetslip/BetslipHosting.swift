//
// BetslipHosting.swift
// FightDeckBetslip
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import SwiftUI

@MainActor
public protocol SlipDisplayContext: AnyObject {
    func fighterName(id: String) -> String
    func opponentName(for selection: Selection) -> String
    func eventName(for selection: Selection) -> String
}

// MARK: - Compose (Android)

#if SKIP
public struct BetslipComposeEntry: View {
    public let store: BetSlipStore
    public let display: SlipDisplayContext
    public let theme: ThemeTokens
    public let onDeposit: @Sendable () -> Void
    public let onBrowseEvents: @Sendable () -> Void
    public let onHostSync: @Sendable (BetSlip, Decimal, String?) -> Void

    public init(
        store: BetSlipStore,
        display: SlipDisplayContext,
        theme: ThemeTokens,
        onDeposit: @escaping @Sendable () -> Void,
        onBrowseEvents: @escaping @Sendable () -> Void,
        onHostSync: @escaping @Sendable (BetSlip, Decimal, String?) -> Void
    ) {
        self.store = store
        self.display = display
        self.theme = theme
        self.onDeposit = onDeposit
        self.onBrowseEvents = onBrowseEvents
        self.onHostSync = onHostSync
    }

    public var body: some View {
        BetSlipRootView(
            store: store,
            display: display,
            theme: theme,
            onDeposit: onDeposit,
            onBrowseEvents: onBrowseEvents,
            onHostSync: onHostSync
        )
    }
}
#endif
