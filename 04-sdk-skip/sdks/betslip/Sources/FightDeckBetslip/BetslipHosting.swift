//
// BetslipHosting.swift
// FightDeckBetslip
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import SwiftUI

@MainActor
public protocol SlipDisplayContext: AnyObject {
    func fighterName(id: String) -> String
    func opponentName(for selection: Selection) -> String
    func eventName(for selection: Selection) -> String
}
