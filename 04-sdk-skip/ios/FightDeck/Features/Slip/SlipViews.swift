//
// SlipViews.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import FightDeckCore
import SwiftUI
#if FIGHTDECK_BOTH
import FightDeckBetslip
#endif
#if FIGHTDECK_DEPOSIT || FIGHTDECK_BOTH
import FightDeckDeposit
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
        FeatureUnavailableView(label: "Bet slip")
        #endif
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

    @State private var store: BetSlipStore?

    var body: some View {
        Group {
            if let store {
                BetSlipRootView(
                    store: store,
                    display: HostSlipDisplayContext(state: state),
                    theme: BetslipTheme.parse(ThemeLoader.tokensJSON()),
                    onDeposit: { path.append(.deposit) },
                    onBrowseEvents: onBrowseEvents,
                    onHostSync: { slip, balance, message in
                        state.applySdkSlip(slip, balance: balance, betPlacedMessage: message)
                    }
                )
            }
        }
        .background(DesignTokens.ColorToken.background)
        .onAppear { ensureStore() }
        .onChange(of: state.slip) { _, newSlip in
            store?.slip = newSlip
        }
        .onChange(of: state.balance) { _, newBalance in
            store?.balance = newBalance
        }
    }

    private func ensureStore() {
        guard store == nil else { return }
        store = BetSlipStore(
            fightCore: state.fightCore,
            slip: state.slip,
            balance: state.balance
        )
    }
}

@MainActor
final class HostSlipDisplayContext: SlipDisplayContext {
    private let state: AppState

    init(state: AppState) {
        self.state = state
    }

    func fighterName(id: String) -> String {
        guard case .loaded(let fighters) = state.fightersState,
              let fighter = fighters.first(where: { $0.id == id }) else {
            return id
        }
        return fighter.name
    }

    func opponentName(for selection: Selection) -> String {
        guard case .loaded(let events) = state.eventsState else { return "—" }
        for event in events {
            if let bout = event.bouts.first(where: { $0.id == selection.boutID }) {
                let opponentID = bout.redCorner.fighterId == selection.fighterID
                    ? bout.blueCorner.fighterId : bout.redCorner.fighterId
                return fighterName(id: opponentID)
            }
        }
        return "—"
    }

    func eventName(for selection: Selection) -> String {
        guard case .loaded(let events) = state.eventsState,
              let event = events.first(where: { $0.bouts.contains { $0.id == selection.boutID } }) else {
            return "—"
        }
        return event.name
    }
}
#endif

#if FIGHTDECK_DEPOSIT || FIGHTDECK_BOTH
struct DepositBridgeView: View {
    @Bindable var state: AppState
    @Binding var path: [SlipRoute]

    var body: some View {
        DepositSDKView(state: state) {
            path.removeAll()
        }
        .ignoresSafeArea()
    }
}

struct DepositSDKView: UIViewControllerRepresentable {
    @Bindable var state: AppState
    let onDone: () -> Void

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
                if case .completed(let amount) = result {
                    state.deposit(amount: amount)
                    onDone()
                }
            }
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
#endif
