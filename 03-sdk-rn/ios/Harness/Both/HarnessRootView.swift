//
// HarnessRootView.swift
// FightDeckHarnessBoth
//
// Created by FightDeck on 12.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import BetslipSDK
import DepositSDK
import FightDeckRNRuntime
import SwiftUI
import UIKit

// Second-feature stage: runtime plus both feature SDKs. Subtracting the deposit stage from
// this one is the "what does the next screen cost" number, and it comes out tiny because
// both surfaces run on the Hermes runtime the first stage already paid for.
struct HarnessRootView: View {
    var body: some View {
        TabView {
            HarnessSurface { onResult in
                let hosting: DepositHosting = DepositAdapter()
                hosting.configure()
                FightDeckRuntime.shared.prewarm()
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
        }
    }
}
