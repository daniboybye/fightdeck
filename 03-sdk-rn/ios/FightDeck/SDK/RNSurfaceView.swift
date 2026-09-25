//
// RNSurfaceView.swift
// FightDeck
//
// Created by FightDeck on 23.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI
import UIKit

/// Every React Native surface in the app is mounted through this one view. `update` hands the
/// adapter new parameters, and the adapter drops the ones that change nothing, because
/// properties re-render the surface from its root.
///
/// Nothing else crosses: SwiftUI keeps the surface clear of the navigation bar, the tab bar and
/// the keyboard, so the React screen lays out against its own edges.
struct RNSurfaceView: UIViewControllerRepresentable {
    let make: @MainActor () -> UIViewController
    let update: @MainActor () -> Void

    func makeUIViewController(context: Context) -> RNSurfaceWrapperViewController {
        SDKBootstrap.shared.configureOnce()
        return RNSurfaceWrapperViewController(childController: make())
    }

    func updateUIViewController(_ wrapper: RNSurfaceWrapperViewController, context: Context) {
        update()
    }
}

/// Hosts the cached RN controller.
@MainActor
final class RNSurfaceWrapperViewController: UIViewController {
    let childController: UIViewController

    init(childController: UIViewController) {
        self.childController = childController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemGroupedBackground
        adoptChildController()
    }

    /// The React Native host caches one surface per module, so the same controller comes back
    /// every time SwiftUI rebuilds this screen. Adopting a child that still belongs to the
    /// previous wrapper leaves its view in a hierarchy that is no longer on screen — which is
    /// what a blank surface looks like.
    private func adoptChildController() {
        if childController.parent != nil {
            childController.willMove(toParent: nil)
            childController.view.removeFromSuperview()
            childController.removeFromParent()
        }
        addChild(childController)
        childController.view.translatesAutoresizingMaskIntoConstraints = false
        childController.view.backgroundColor = .clear
        view.addSubview(childController.view)
        NSLayoutConstraint.activate([
            childController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            childController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            childController.view.topAnchor.constraint(equalTo: view.topAnchor),
            childController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        childController.didMove(toParent: self)
    }
}
