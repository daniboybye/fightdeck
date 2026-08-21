//
// SlipViews.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
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
                .navigationDestination(for: SlipRoute.self) { route in
                    if route == .deposit {
                        #if FIGHTDECK_DEPOSIT || FIGHTDECK_BOTH
                        DepositBridgeView(state: state, path: $path)
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
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("No selections yet")
                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            Button("Browse Events", action: onBrowseEvents)
                .buttonStyle(PrimaryCapsuleButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.ColorToken.background)
    }
}

private struct FeatureUnavailableView: View {
    let label: String

    var body: some View {
        Text("\(label) not included in this build")
            .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.ColorToken.background)
    }
}

#if FIGHTDECK_BOTH
struct BetslipBridgeView: View {
    @Bindable var state: AppState
    @Binding var path: [SlipRoute]
    let onBrowseEvents: () -> Void

    var body: some View {
        BetslipSDKView(state: state, path: $path, onBrowseEvents: onBrowseEvents)
            .ignoresSafeArea()
    }
}

struct BetslipSDKView: UIViewControllerRepresentable {
    @Bindable var state: AppState
    @Binding var path: [SlipRoute]
    let onBrowseEvents: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        SDKBootstrap.shared.configureOnce()
        let slipJSON = (try? JSONEncoder().encode(SlipPayload(from: state.slip))).flatMap {
            String(data: $0, encoding: .utf8)
        } ?? "{}"
        let eventsJSON = (try? String(contentsOf: DatasetLocator.eventsURL())) ?? "{\"events\":[]}"
        let params = BetslipParams(
            accessToken: "demo-token",
            environment: "demo",
            locale: Locale.current.identifier,
            themeJSON: ThemeLoader.tokensJSON(),
            balance: state.balance,
            slipJSON: slipJSON,
            eventsJSON: eventsJSON
        )
        return SDKBootstrap.shared.betslipHosting.makeViewController(params: params) { result in
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
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
#endif

#if FIGHTDECK_DEPOSIT || FIGHTDECK_BOTH
struct DepositBridgeView: View {
    @Bindable var state: AppState
    @Binding var path: [SlipRoute]

    var body: some View {
        DepositSDKView(state: state, path: $path)
            .ignoresSafeArea()
    }
}

struct DepositSDKView: UIViewControllerRepresentable {
    @Bindable var state: AppState
    @Binding var path: [SlipRoute]

    func makeUIViewController(context: Context) -> UIViewController {
        SDKBootstrap.shared.configureOnce()
        let params = DepositParams(
            accessToken: "demo-token",
            environment: "demo",
            locale: Locale.current.identifier,
            themeJSON: ThemeLoader.tokensJSON(),
            currentBalance: state.balance
        )
        return SDKBootstrap.shared.depositHosting.makeViewController(params: params) { result in
            Task { @MainActor in
                switch result {
                case .completed(let amount):
                    state.deposit(amount: amount)
                    path.removeAll()
                case .cancelled, .failed:
                    break
                }
            }
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
#endif
