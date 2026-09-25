//
// RNSurfaceView.swift
// FightDeck
//
// Created by FightDeck on 23.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckRNRuntime
import SwiftUI
import UIKit

/// Every React Native surface in the app is mounted through this one view. `update` hands the
/// adapter new parameters, and the adapter drops the ones that change nothing, because
/// properties re-render the surface from its root.
///
/// Nothing else crosses: SwiftUI keeps the surface clear of the navigation bar, the tab bar and
/// the keyboard, so the React screen lays out against its own edges. Each showing makes its
/// own surface and stops it when SwiftUI lets go, as the Compose host does.
struct RNSurfaceView: UIViewControllerRepresentable {
    let make: @MainActor () -> UIViewController
    let update: @MainActor () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        SDKBootstrap.shared.configureOnce()
        return make()
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        update()
    }

    static func dismantleUIViewController(_ controller: UIViewController, coordinator: Void) {
        FightDeckRuntime.shared.stop(controller)
    }
}
