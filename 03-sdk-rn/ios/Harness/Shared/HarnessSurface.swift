//
// HarnessSurface.swift
// FightDeckHarness
//
// Created by FightDeck on 12.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI
import UIKit

/// Hosts one SDK view controller. The demo app's `RNSurfaceWrapperViewController` re-adopts
/// the runtime's cached controller when SwiftUI rebuilds a screen; a harness shows each
/// surface once, so it needs none of that.
struct HarnessSurface: UIViewControllerRepresentable {
    let make: (@escaping () -> Void) -> UIViewController

    func makeUIViewController(context: Context) -> UIViewController {
        make {}
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
