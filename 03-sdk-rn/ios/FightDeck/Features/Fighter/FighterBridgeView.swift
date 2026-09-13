//
// FighterBridgeView.swift
// FightDeck
//
// Created by FightDeck on 13.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FighterSDK
import FightDeckRNRuntime
import SwiftUI

struct FighterBridgeView: View {
    @Bindable var state: AppState
    let fighterID: String
    @State private var layoutMetrics = RNSurfaceLayoutMetrics()

    var body: some View {
        Group {
            if state.fighter(fighterID) != nil {
                RNSurfaceLayoutReader(metrics: $layoutMetrics) {
                    FighterSDKView(
                        state: state,
                        fighterID: fighterID,
                        layoutMetrics: layoutMetrics
                    )
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(state.fighter(fighterID)?.name ?? "Fighter")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FighterSDKView: UIViewControllerRepresentable {
    @Bindable var state: AppState
    let fighterID: String
    var layoutMetrics: RNSurfaceLayoutMetrics

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        SDKBootstrap.shared.configureOnce()
        let surface = SDKBootstrap.shared.fighterHosting.makeViewController(
            params: fighterParams(for: nil)
        ) { _ in }
        let wrapper = RNSurfaceWrapperViewController(childController: surface)
        wrapper.onLayout = { [weak wrapper] in
            guard let wrapper else { return }
            Task { @MainActor in
                context.coordinator.pushLayout(to: wrapper, parent: self)
            }
        }
        context.coordinator.wrapper = wrapper
        DispatchQueue.main.async {
            context.coordinator.pushLayout(to: wrapper, parent: self)
        }
        return wrapper
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard let wrapper = uiViewController as? RNSurfaceWrapperViewController else {
            return
        }
        context.coordinator.pushLayout(to: wrapper, parent: self)
    }

    fileprivate func fighterParams(
        for controller: UIViewController?,
        layoutStamp: Double = 0
    ) -> FighterParams {
        let layout = SurfaceChrome.resolve(layoutMetrics, for: controller)
        let fighter = state.fighter(fighterID)
        let fighterJSON = fighter.flatMap { try? String(data: JSONEncoder().encode($0), encoding: .utf8) } ?? "{}"
        let portraitURL = fighter.flatMap { state.imageURL($0.portrait)?.absoluteString } ?? ""
        return FighterParams(
            themeJSON: ThemeLoader.tokensJSON(),
            fighterJSON: fighterJSON,
            portraitURL: portraitURL,
            safeAreaTop: layout.safeAreaTop,
            safeAreaBottom: layout.safeAreaBottom,
            chromeBackground: layout.chromeBackground,
            layoutStamp: layoutStamp
        )
    }

    final class Coordinator {
        var parent: FighterSDKView
        weak var wrapper: RNSurfaceWrapperViewController?
        private var layoutStamp: Double = 0
        private var lastPushed: RNSurfacePropsFingerprint?

        init(parent: FighterSDKView) {
            self.parent = parent
        }

        @MainActor
        func pushLayout(to wrapper: RNSurfaceWrapperViewController, parent: FighterSDKView) {
            layoutStamp += 1
            let params = parent.fighterParams(for: wrapper, layoutStamp: layoutStamp)
            let fingerprint = RNSurfacePropsFingerprint(params)
            if fingerprint.data != lastPushed?.data {
                SDKBootstrap.shared.fighterHosting.update(params: params)
            }
            guard fingerprint.layout != lastPushed?.layout || lastPushed == nil else {
                lastPushed = fingerprint
                return
            }
            lastPushed = fingerprint
            RNSurfaceLayoutPush.deliver(
                moduleName: "FighterFeature",
                layout: RNSurfaceLayoutSnapshot(
                    safeAreaTop: params.safeAreaTop,
                    safeAreaBottom: params.safeAreaBottom,
                    keyboardBottomInset: 0,
                    chromeBackground: params.chromeBackground
                ),
                textInputActive: false,
                layoutStamp: params.layoutStamp
            )
        }
    }
}
