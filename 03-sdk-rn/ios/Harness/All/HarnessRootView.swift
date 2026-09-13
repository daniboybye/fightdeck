//
// HarnessRootView.swift
// FightDeckHarnessAll
//
// Created by FightDeck on 13.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import BetslipSDK
import DepositSDK
import FighterSDK
import FightDeckRNRuntime
import SwiftUI
import UIKit

struct HarnessRootView: View {
    var body: some View {
        TabView {
            HarnessSurface { onResult in
                let hosting: DepositHosting = DepositAdapter()
                hosting.configure()
                FightDeckRNRuntime.shared.prewarm()
                return hosting.makeViewController(
                    params: DepositParams(
                        themeJSON: "{}",
                        currentBalance: 500
                    ),
                    onResult: { _ in onResult() }
                )
            }
            HarnessSurface { onResult in
                let hosting: BetslipHosting = BetslipAdapter()
                hosting.configure()
                return hosting.makeViewController(
                    params: BetslipParams(
                        themeJSON: "{}",
                        balance: 500,
                        slipJSON: "{}",
                        eventsJSON: "{\"events\":[]}"
                    ),
                    onResult: { _ in onResult() }
                )
            }
            HarnessSurface { onResult in
                let hosting: FighterHosting = FighterAdapter()
                hosting.configure()
                return hosting.makeViewController(
                    params: FighterParams(
                        themeJSON: "{}",
                        fighterJSON: """
                        {"name":"Sample Fighter","record":{"wins":20,"losses":2,"noContests":0,"display":"20-2-0"}}
                        """,
                        portraitURL: ""
                    ),
                    onResult: { _ in onResult() }
                )
            }
        }
    }
}
