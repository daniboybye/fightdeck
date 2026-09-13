//
// ContractLimits.swift
// FightCore
//
// Created by FightDeck on 13.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

public struct ContractLimits: Sendable {
    public static let minStake = Decimal(string: "1.00")!
    public static let maxStake = Decimal(string: "5000.00")!
    public static let maxSelections = 12
    public static let minAccaLegs = 2
    public static let maxPayout = Decimal(string: "100000.00")!
    public static let cashOutMargin = Decimal(string: "0.05")!
}
