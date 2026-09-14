//
// HarnessRootView.swift
// FightDeckHarnessRuntime
//
// Created by FightDeck on 12.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckRNRuntime
import SwiftUI

// Runtime stage: React Native and Hermes linked, no feature SDK. This is the number the
// talk leads with — what an embedded RN runtime costs before a single feature screen
// exists — so it has to actually start the runtime rather than merely link it.
struct HarnessRootView: View {
    @State private var summary = "starting"

    var body: some View {
        Text(summary)
            .task {
                FightDeckRuntime.shared.prewarm()
                let metrics = FightDeckRuntime.shared.startupMetrics()
                summary = "prewarm \(Int(metrics.prewarmedMilliseconds))ms"
            }
    }
}
