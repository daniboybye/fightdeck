//
// BetslipHosting.swift
// FightDeckBetslip
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import FightDeckCore
import SwiftUI
#if !SKIP
import UIKit
#endif

public struct BetslipParams: Sendable {
    public let themeJSON: String
    public let fightCore: FightCore
    public let initialSlip: BetSlip
    public let initialBalance: Decimal

    public init(
        themeJSON: String,
        fightCore: FightCore,
        initialSlip: BetSlip,
        initialBalance: Decimal
    ) {
        self.themeJSON = themeJSON
        self.fightCore = fightCore
        self.initialSlip = initialSlip
        self.initialBalance = initialBalance
    }
}

@MainActor
public protocol SlipDisplayContext: AnyObject {
    func fighterName(id: String) -> String
    func opponentName(for selection: Selection) -> String
    func eventName(for selection: Selection) -> String
}

#if !SKIP
public protocol BetslipHosting: AnyObject {
    func configure()
    @MainActor
    func makeViewController(
        params: BetslipParams,
        display: SlipDisplayContext,
        onDeposit: @escaping @Sendable () -> Void,
        onBrowseEvents: @escaping @Sendable () -> Void,
        onHostSync: @escaping @Sendable (BetSlip, Decimal, String?) -> Void
    ) -> UIViewController
}

public final class SkipBetslipHosting: BetslipHosting {
    public init() {}

    public func configure() {}

    @MainActor
    public func makeViewController(
        params: BetslipParams,
        display: SlipDisplayContext,
        onDeposit: @escaping @Sendable () -> Void,
        onBrowseEvents: @escaping @Sendable () -> Void,
        onHostSync: @escaping @Sendable (BetSlip, Decimal, String?) -> Void
    ) -> UIViewController {
        let store = BetSlipStore(
            fightCore: params.fightCore,
            slip: params.initialSlip,
            balance: params.initialBalance
        )
        let theme = BetslipTheme.parse(params.themeJSON)
        let view = BetSlipRootView(
            store: store,
            display: display,
            theme: theme,
            onDeposit: onDeposit,
            onBrowseEvents: onBrowseEvents,
            onHostSync: onHostSync
        )
        return UIHostingController(rootView: view)
    }
}
#endif

#if SKIP
public struct BetslipComposeEntry: View {
    public let store: BetSlipStore
    public let display: SlipDisplayContext
    public let theme: BetslipTheme
    public let onDeposit: @Sendable () -> Void
    public let onBrowseEvents: @Sendable () -> Void
    public let onHostSync: @Sendable (BetSlip, Decimal, String?) -> Void

    public init(
        store: BetSlipStore,
        display: SlipDisplayContext,
        theme: BetslipTheme,
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
