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
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                FightDeckRNRuntime.shared.onHostResume()
            case .inactive, .background:
                FightDeckRNRuntime.shared.onHostPause()
            @unknown default:
                break
            }
        }
    }
}
