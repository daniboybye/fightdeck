//
// SDKBootstrap.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import FightDeckRNRuntime
import Foundation
import UIKit
#if FIGHTDECK_DEPOSIT || FIGHTDECK_BOTH
import DepositSDK
#endif
#if FIGHTDECK_BOTH
import BetslipSDK
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

enum AccessTokenService {
    static func fetchToken(environment: String) async throws -> String {
        try await Task.sleep(for: .milliseconds(120))
        return environment == "fail" ? "fail" : "demo-token"
    }
}

#if FIGHTDECK_DEPOSIT || FIGHTDECK_BOTH
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
            paramsBuilder: {
                let token = try await AccessTokenService.fetchToken(environment: "demo")
                return DepositParams(
                    accessToken: token,
                    environment: "demo",
                    locale: Locale.current.identifier,
                    themeJSON: ThemeLoader.tokensJSON(),
                    currentBalance: balance
                )
            },
            onResult: onResult
        )
    }
}
#endif

@MainActor
final class SDKBootstrap {
    static let shared = SDKBootstrap()

    #if FIGHTDECK_DEPOSIT || FIGHTDECK_BOTH
    let depositHosting: DepositHosting = DepositAdapter()
    #endif
    #if FIGHTDECK_BOTH
    let betslipHosting: BetslipHosting = BetslipAdapter()
    #endif

    private var didConfigure = false

    static var shouldSkipRNPrewarm: Bool {
        ProcessInfo.processInfo.arguments.contains("-SkipRNPrewarm")
            || ProcessInfo.processInfo.environment["FIGHTDECK_SKIP_RN_PREWARM"] == "1"
    }

    func configureOnce() {
        guard !didConfigure else { return }
        #if FIGHTDECK_DEPOSIT || FIGHTDECK_BOTH
        depositHosting.configure()
        #endif
        #if FIGHTDECK_BOTH
        betslipHosting.configure()
        #endif
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
