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
import UIKit

enum ThemeLoader {
    static func tokensJSON() -> String {
        DatasetLocator.tokensJSON()
    }
}

@MainActor
enum DepositLauncherHost {
    static func launch(
        navigationController: UINavigationController,
        hosting: DepositHosting,
        balance: Decimal,
        onResult: @escaping @Sendable (DepositResult) -> Void
    ) {
        DepositLauncher.launch(
            from: navigationController,
            hosting: hosting,
            params: DepositParams(
                themeJSON: ThemeLoader.tokensJSON(),
                currentBalance: balance
            ),
            onResult: onResult
        )
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
            FightDeckRNRuntime.shared.prewarm()
        }
        let metrics = FightDeckRNRuntime.shared.startupMetrics()
        NSLog(
            "[FightDeckStartup] prewarm=%.0fms cold=%.0fms skipPrewarm=%@",
            metrics.prewarmedMilliseconds,
            metrics.coldMilliseconds,
            Self.shouldSkipRNPrewarm ? "true" : "false"
        )
        didConfigure = true
    }
}
