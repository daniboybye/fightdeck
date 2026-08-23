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

    var body: some View {
        BetslipSDKView(state: state, path: $path, onBrowseEvents: onBrowseEvents)
            // TabView can instantiate every tab at launch; recreating the surface when the
            // host slip changes keeps the RN module in sync with native odds taps.
            .id(slipIdentity)
            .ignoresSafeArea()
    }

    private var slipIdentity: String {
        state.slip.selections
            .map { "\($0.boutID):\($0.fighterID)" }
            .joined(separator: ",")
            + "|\(Money.format(state.slip.stake))"
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
    @State private var depositConfirmed = false

    var body: some View {
        DepositSDKView(state: state, path: $path, onConfirmed: { depositConfirmed = true })
            .ignoresSafeArea()
            // The money has already moved by the time this screen appears, so going back to
            // the amount field would offer to spend it a second time.
            .navigationBarBackButtonHidden(depositConfirmed)
    }
}

struct DepositSDKView: UIViewControllerRepresentable {
    @Bindable var state: AppState
    @Binding var path: [SlipRoute]
    var onConfirmed: () -> Void

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
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
#endif
