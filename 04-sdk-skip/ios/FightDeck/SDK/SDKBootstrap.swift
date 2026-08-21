//
// SDKBootstrap.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import Foundation
#if FIGHTDECK_DEPOSIT || FIGHTDECK_BOTH
import FightDeckDeposit
#endif
#if FIGHTDECK_BOTH
import FightDeckBetslip
#endif

enum ThemeLoader {
    static func tokensJSON() -> String {
        let url = DatasetLocator.datasetRoot()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("shared-ui-spec/tokens.json")
        return (try? String(contentsOf: url, encoding: .utf8)) ?? "{}"
    }
}

@MainActor
final class SDKBootstrap {
    static let shared = SDKBootstrap()

    #if FIGHTDECK_DEPOSIT || FIGHTDECK_BOTH
    let depositHosting: DepositHosting = SkipDepositHosting()
    #endif
    #if FIGHTDECK_BOTH
    let betslipHosting: BetslipHosting = SkipBetslipHosting()
    #endif

    private var didConfigure = false

    func configureOnce() {
        guard !didConfigure else { return }
        #if FIGHTDECK_DEPOSIT || FIGHTDECK_BOTH
        depositHosting.configure()
        #endif
        #if FIGHTDECK_BOTH
        betslipHosting.configure()
        #endif
        didConfigure = true
    }
}
