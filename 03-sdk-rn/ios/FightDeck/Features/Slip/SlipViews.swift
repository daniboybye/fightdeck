//
// SlipViews.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckRNRuntime
import SwiftUI
#if FIGHTDECK_BOTH
import BetslipSDK
#endif
#if FIGHTDECK_DEPOSIT || FIGHTDECK_BOTH
import DepositSDK
#endif

struct SlipTabView: View {
    @Bindable var state: AppState
    @Binding var path: [SlipRoute]
    let onBrowseEvents: () -> Void

    var body: some View {
        NavigationStack(path: $path) {
            slipRoot
                .navigationTitle("Bet Slip")
                // A large title collapses as its scroll view moves, and the nav bar can only
                // watch a SwiftUI scroll view. React Native owns this one, so a large title
                // would hang there at full size while the content slid underneath it.
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: SlipRoute.self) { route in
                    if route == .deposit {
                        #if FIGHTDECK_DEPOSIT || FIGHTDECK_BOTH
                        DepositBridgeView(state: state, path: $path)
                            // The deposit flow is a single self-contained task; the tab bar would
                            // invite the user to abandon it half-way.
                            .toolbar(.hidden, for: .tabBar)
                        #else
                        FeatureUnavailableView(label: "Deposit")
                            .toolbar(.hidden, for: .tabBar)
                        #endif
                    }
                }
        }
    }

    @ViewBuilder
    private var slipRoot: some View {
        #if FIGHTDECK_BOTH
        BetslipBridgeView(state: state, path: $path, onBrowseEvents: onBrowseEvents)
        #else
        SlipPlaceholderView(onBrowseEvents: onBrowseEvents)
        #endif
    }
}

private struct SlipPlaceholderView: View {
    let onBrowseEvents: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No selections yet", systemImage: "ticket")
        } description: {
            Text("Pick a winner on any upcoming bout and it lands here.")
        } actions: {
            Button("Browse Events", action: onBrowseEvents)
                .buttonStyle(.glassProminent)
        }
    }
}

private struct FeatureUnavailableView: View {
    let label: String

    var body: some View {
        ContentUnavailableView {
            Label("\(label) not included", systemImage: "exclamationmark.triangle")
        } description: {
            Text("This build variant does not ship the \(label.lowercased()) SDK.")
        }
    }
}

#if FIGHTDECK_BOTH
struct BetslipBridgeView: View {
    @Bindable var state: AppState
    @Binding var path: [SlipRoute]
    let onBrowseEvents: () -> Void
    @State private var layoutMetrics = RNSurfaceLayoutMetrics()
    @State private var textInputActive = false

    var body: some View {
        RNSurfaceLayoutReader(metrics: $layoutMetrics) {
            BetslipSDKView(
                state: state,
                path: $path,
                onBrowseEvents: onBrowseEvents,
                layoutMetrics: layoutMetrics,
                textInputActive: textInputActive
            )
        }
        .onAppear {
            layoutMetrics.includesTabBarClearance = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { _ in
            textInputActive = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidEndEditingNotification)) { _ in
            textInputActive = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            textInputActive = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            textInputActive = false
        }
    }
}

struct BetslipSDKView: UIViewControllerRepresentable {
    @Bindable var state: AppState
    @Binding var path: [SlipRoute]
    let onBrowseEvents: () -> Void
    var layoutMetrics: RNSurfaceLayoutMetrics
    var textInputActive: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        SDKBootstrap.shared.configureOnce()
        let surface = SDKBootstrap.shared.betslipHosting.makeViewController(
            params: betslipParams(for: nil)
        ) { result in
            Task { @MainActor in
                switch result {
                case .updated(let slipJSON):
                    state.applySlipJSON(slipJSON)
                case .browseEvents:
                    onBrowseEvents()
                case .deposit:
                    path.append(.deposit)
                case .placed(let message, let slipJSON, let balance):
                    state.placeBetFromSDK(message: message, slipJSON: slipJSON, balanceString: balance)
                case .cancelled:
                    break
                }
            }
        }
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

    fileprivate func betslipParams(
        for controller: UIViewController?,
        layoutStamp: Double = 0
    ) -> BetslipParams {
        let editing = textInputActive || RNSurfaceLayoutProbe.isTextInputActive(for: controller)
        let layout = SurfaceChrome.resolve(layoutMetrics, for: controller)
        let slipJSON = (try? JSONEncoder().encode(SlipPayload(from: state.slip))).flatMap {
            String(data: $0, encoding: .utf8)
        } ?? "{}"
        let eventsJSON = (try? String(contentsOf: DatasetLocator.eventsURL())) ?? "{\"events\":[]}"
        return BetslipParams(
            accessToken: "demo-token",
            environment: "demo",
            locale: Locale.current.identifier,
            themeJSON: ThemeLoader.tokensJSON(),
            balance: state.balance,
            slipJSON: slipJSON,
            eventsJSON: eventsJSON,
            betPlacedMessage: state.betPlacedMessage ?? "",
            safeAreaTop: layout.safeAreaTop,
            safeAreaBottom: layout.safeAreaBottom,
            keyboardBottomInset: layout.keyboardBottomInset,
            chromeBackground: layout.chromeBackground,
            textInputActive: editing,
            layoutStamp: layoutStamp
        )
    }

    final class Coordinator {
        var parent: BetslipSDKView
        weak var wrapper: RNSurfaceWrapperViewController?
        private var layoutStamp: Double = 0
        private var lastPushed: RNSurfacePropsFingerprint?

        init(parent: BetslipSDKView) {
            self.parent = parent
        }

        @MainActor
        func pushLayout(to wrapper: RNSurfaceWrapperViewController, parent: BetslipSDKView) {
            layoutStamp += 1
            let params = parent.betslipParams(for: wrapper, layoutStamp: layoutStamp)
            let fingerprint = RNSurfacePropsFingerprint(params)
            if fingerprint.data != lastPushed?.data {
                SDKBootstrap.shared.betslipHosting.update(params: params)
            }
            guard fingerprint.layout != lastPushed?.layout || lastPushed == nil else {
                lastPushed = fingerprint
                return
            }
            lastPushed = fingerprint
            RNSurfaceLayoutPush.deliver(
                moduleName: "BetslipFeature",
                layout: RNSurfaceLayoutSnapshot(
                    safeAreaTop: params.safeAreaTop,
                    safeAreaBottom: params.safeAreaBottom,
                    keyboardBottomInset: params.keyboardBottomInset,
                    chromeBackground: params.chromeBackground
                ),
                textInputActive: params.textInputActive,
                layoutStamp: params.layoutStamp
            )
        }
    }
}
#endif

#if FIGHTDECK_DEPOSIT || FIGHTDECK_BOTH
struct DepositBridgeView: View {
    @Bindable var state: AppState
    @Binding var path: [SlipRoute]
    @State private var depositConfirmed = false
    @State private var layoutMetrics = {
        var metrics = RNSurfaceLayoutMetrics()
        metrics.includesTabBarClearance = false
        return metrics
    }()
    @State private var textInputActive = false

    var body: some View {
        RNSurfaceLayoutReader(metrics: $layoutMetrics) {
            DepositSDKView(
                state: state,
                path: $path,
                onConfirmed: { depositConfirmed = true },
                layoutMetrics: layoutMetrics,
                textInputActive: textInputActive
            )
        }
        .navigationTitle(depositConfirmed ? "Confirmed" : "Deposit")
        .navigationBarTitleDisplayMode(.inline)
        // The money has already moved by the time this screen appears, so going back to
        // the amount field would offer to spend it a second time.
        .navigationBarBackButtonHidden(depositConfirmed)
        .onAppear {
            layoutMetrics.includesTabBarClearance = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { _ in
            textInputActive = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidEndEditingNotification)) { _ in
            textInputActive = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            textInputActive = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            textInputActive = false
        }
    }
}

struct DepositSDKView: UIViewControllerRepresentable {
    @Bindable var state: AppState
    @Binding var path: [SlipRoute]
    var onConfirmed: () -> Void
    var layoutMetrics: RNSurfaceLayoutMetrics
    var textInputActive: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        SDKBootstrap.shared.configureOnce()
        let surface = SDKBootstrap.shared.depositHosting.makeViewController(
            params: depositParams(for: nil)
        ) { result in
            Task { @MainActor in
                switch result {
                case .confirmed:
                    onConfirmed()
                case .completed(let amount):
                    state.deposit(amount: amount)
                    path.removeAll()
                case .cancelled, .failed:
                    break
                }
            }
        }
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

    fileprivate func depositParams(
        for controller: UIViewController?,
        layoutStamp: Double = 0
    ) -> DepositParams {
        let editing = textInputActive || RNSurfaceLayoutProbe.isTextInputActive(for: controller)
        let layout = SurfaceChrome.resolve(layoutMetrics, for: controller)
        return DepositParams(
            accessToken: "demo-token",
            environment: "demo",
            locale: Locale.current.identifier,
            themeJSON: ThemeLoader.tokensJSON(),
            currentBalance: state.balance,
            safeAreaTop: layout.safeAreaTop,
            safeAreaBottom: layout.safeAreaBottom,
            keyboardBottomInset: layout.keyboardBottomInset,
            chromeBackground: layout.chromeBackground,
            textInputActive: editing,
            layoutStamp: layoutStamp
        )
    }

    final class Coordinator {
        var parent: DepositSDKView
        weak var wrapper: RNSurfaceWrapperViewController?
        private var layoutStamp: Double = 0
        private var lastPushed: RNSurfacePropsFingerprint?

        init(parent: DepositSDKView) {
            self.parent = parent
        }

        @MainActor
        func pushLayout(to wrapper: RNSurfaceWrapperViewController, parent: DepositSDKView) {
            layoutStamp += 1
            let params = parent.depositParams(for: wrapper, layoutStamp: layoutStamp)
            let fingerprint = RNSurfacePropsFingerprint(params)
            if fingerprint.data != lastPushed?.data {
                SDKBootstrap.shared.depositHosting.update(params: params)
            }
            guard fingerprint.layout != lastPushed?.layout || lastPushed == nil else {
                lastPushed = fingerprint
                return
            }
            lastPushed = fingerprint
            RNSurfaceLayoutPush.deliver(
                moduleName: "DepositFeature",
                layout: RNSurfaceLayoutSnapshot(
                    safeAreaTop: params.safeAreaTop,
                    safeAreaBottom: params.safeAreaBottom,
                    keyboardBottomInset: params.keyboardBottomInset,
                    chromeBackground: params.chromeBackground
                ),
                textInputActive: params.textInputActive,
                layoutStamp: params.layoutStamp
            )
        }
    }
}
#endif
