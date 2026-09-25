//
// HarnessSurface.swift
// FightDeckHarness
//
// Created by FightDeck on 12.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI
import UIKit

/// Hosts one SDK view controller. A harness shows each surface once and never lets it go, so
/// unlike the demo app's `RNSurfaceView` it has nothing to stop.
struct HarnessSurface: UIViewControllerRepresentable {
    let make: (@escaping () -> Void) -> UIViewController

    func makeUIViewController(context: Context) -> UIViewController {
        make {}
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
