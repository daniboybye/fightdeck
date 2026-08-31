//
// Typography.swift
// FightDeckCore
//
// Created by FightDeck on 28.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI

public enum Typography {
    public static func body(_ size: CGFloat) -> Font {
        Font.system(size: size)
    }

    public static func bold(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: Font.Weight.bold)
    }

    public static func semibold(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: Font.Weight.semibold)
    }

    public static func medium(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: Font.Weight.medium)
    }
}
