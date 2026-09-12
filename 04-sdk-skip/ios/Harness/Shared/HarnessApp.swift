//
// HarnessApp.swift
// FightDeckHarness
//
// Created by FightDeck on 12.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI

// The size-measurement host, and the reason the demo app carries no conditional
// compilation. `tools/measure-second-feature.sh` weighs a host that links the runtime
// alone against one that also links deposit and one that links both, and subtracts. Doing
// that inside FightDeck itself meant every feature screen needed an #else branch for a
// configuration that never shipped.
//
// Exactly one HarnessRootView is compiled per target: Harness/Runtime, Harness/Deposit or
// Harness/Both. Same trick the Android hosts use with flavour source sets — different
// files, not different branches inside one file.
//
// Nothing here is a product surface. It renders whatever is cheapest that still keeps the
// linker from dead-stripping the thing being measured.
@main
struct HarnessApp: App {
    var body: some Scene {
        WindowGroup {
            HarnessRootView()
        }
    }
}
