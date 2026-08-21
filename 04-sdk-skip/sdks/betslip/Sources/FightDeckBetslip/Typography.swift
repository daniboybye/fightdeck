//
// Typography.swift
// FightDeckBetslip
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import SwiftUI

enum Typography {
    static func body(_ size: CGFloat) -> Font {
        Font.system(size: size)
    }

    static func bold(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: Font.Weight.bold)
    }

    static func semibold(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: Font.Weight.semibold)
    }

    static func medium(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: Font.Weight.medium)
    }
}
