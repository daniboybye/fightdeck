//
// HarnessRootView.swift
// FightDeckHarnessDeposit
//
// Created by FightDeck on 12.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import DepositSDK
import FightDeckRNRuntime
import SwiftUI
import UIKit

// First-feature stage: runtime plus the deposit SDK. Mounts the real surface, because what
// the feature adds is a native adapter plus a JavaScript entry point in the Hermes bundle,
// and a host that only linked the adapter would miss half of that.
struct HarnessRootView: View {
    var body: some View {
        HarnessSurface { onResult in
            let hosting: DepositHosting = DepositAdapter()
            FightDeckRuntime.shared.prewarm()
            return hosting.makeViewController(
                params: DepositParams(
                    themeJSON: "{}",
                    currentBalance: 500
                ),
                onResult: { _ in onResult() }
            )
        }
    }
}
