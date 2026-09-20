//
// SDKBootstrap.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import BetslipSDK
import DepositSDK
import FighterSDK
import FightDeckRNRuntime
import Foundation

enum ThemeLoader {
    static func tokensJSON() -> String {
        DatasetLocator.tokensJSON()
    }
}

@MainActor
final class SDKBootstrap {
    static let shared = SDKBootstrap()

    let depositHosting: DepositHosting = DepositAdapter()
    let betslipHosting: BetslipHosting = BetslipAdapter()
    let fighterHosting: FighterHosting = FighterAdapter()

    private var didConfigure = false

    static var shouldSkipRNPrewarm: Bool {
        ProcessInfo.processInfo.arguments.contains("-SkipRNPrewarm")
            || ProcessInfo.processInfo.environment["FIGHTDECK_SKIP_RN_PREWARM"] == "1"
    }

    func configureOnce() {
        guard !didConfigure else { return }
        depositHosting.configure()
        betslipHosting.configure()
        fighterHosting.configure()
        if !Self.shouldSkipRNPrewarm {
            FightDeckRuntime.shared.prewarm()
        }
        let metrics = FightDeckRuntime.shared.startupMetrics()
        NSLog(
            "[FightDeckStartup] prewarm=%.0fms cold=%.0fms skipPrewarm=%@",
            metrics.prewarmedMilliseconds,
            metrics.coldMilliseconds,
            Self.shouldSkipRNPrewarm ? "true" : "false"
        )
        didConfigure = true
    }
}
