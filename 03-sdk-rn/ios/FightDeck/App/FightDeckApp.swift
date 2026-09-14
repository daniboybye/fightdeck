//
// FightDeckApp.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckRNRuntime
import SwiftUI

@main
struct FightDeckApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .active:
                FightDeckRuntime.shared.onHostResume()
            case .inactive, .background:
                FightDeckRuntime.shared.onHostPause()
            @unknown default:
                break
            }
        }
    }
}
