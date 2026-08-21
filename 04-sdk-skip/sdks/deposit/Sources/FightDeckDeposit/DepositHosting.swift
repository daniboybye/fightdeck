//
// DepositHosting.swift
// FightDeckDeposit
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import FightDeckCore
import SwiftUI
#if !SKIP
import UIKit
#endif

public struct DepositParams: Sendable {
    public let accessToken: String
    public let environment: String
    public let locale: String
    public let themeJSON: String
    public let currentBalance: Decimal

    public init(
        accessToken: String,
        environment: String,
        locale: String,
        themeJSON: String,
        currentBalance: Decimal
    ) {
        self.accessToken = accessToken
        self.environment = environment
        self.locale = locale
        self.themeJSON = themeJSON
        self.currentBalance = currentBalance
    }
}

public enum DepositResult: Sendable {
    case completed(amount: Decimal)
    case cancelled
    case failed(reason: String)
}

#if !SKIP
public protocol DepositHosting: AnyObject {
    func configure()
    @MainActor
    func makeViewController(
        params: DepositParams,
        onResult: @escaping @Sendable (DepositResult) -> Void
    ) -> UIViewController
}

public final class SkipDepositHosting: DepositHosting {
    public init() {}

    public func configure() {}

    @MainActor
    public func makeViewController(
        params: DepositParams,
        onResult: @escaping @Sendable (DepositResult) -> Void
    ) -> UIViewController {
        let theme = ThemeTokens.parse(params.themeJSON)
        let view = DepositFlowView(params: params, theme: theme, onResult: onResult)
        return UIHostingController(rootView: view)
    }
}
#endif

#if SKIP
public struct DepositComposeEntry: View {
    public let params: DepositParams
    public let onResult: @Sendable (DepositResult) -> Void

    public init(params: DepositParams, onResult: @escaping @Sendable (DepositResult) -> Void) {
        self.params = params
        self.onResult = onResult
    }

    public var body: some View {
        DepositFlowView(
            params: params,
            theme: ThemeTokens.parse(params.themeJSON),
            onResult: onResult
        )
    }
}
#endif
