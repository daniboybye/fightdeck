//
// DepositHosting.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI
import UIKit

struct DepositParams: Sendable {
    let currentBalance: Decimal
}

enum DepositResult: Sendable {
    case completed(amount: Decimal)
    case cancelled
    case failed(reason: String)
}

protocol DepositHosting: AnyObject {
    func configure()
    func makeViewController(
        params: DepositParams,
        onResult: @escaping @Sendable (DepositResult) -> Void
    ) -> UIViewController
}

final class NativeDepositHosting: DepositHosting {
    func configure() {}

    func makeViewController(
        params: DepositParams,
        onResult: @escaping @Sendable (DepositResult) -> Void
    ) -> UIViewController {
        let view = DepositFlowView(params: params, onResult: onResult)
        return UIHostingController(rootView: view)
    }
}
