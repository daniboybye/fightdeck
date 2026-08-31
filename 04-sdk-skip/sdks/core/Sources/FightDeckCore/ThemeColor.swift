//
// ThemeColor.swift
// FightDeckCore
//
// Created by FightDeck on 28.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI

public enum ThemeColor {
    public static func fromHex(_ hex: String) -> Color {
        var filtered = ""
        for character in hex.lowercased() {
            let digit = String(character)
            if "0123456789abcdef".contains(digit) {
                filtered += digit
            }
        }
        guard filtered.count >= 6 else {
            return fromHex("#0B0E14")
        }
        let start = filtered.startIndex
        let redHex = String(filtered[start ..< filtered.index(start, offsetBy: 2)])
        let greenHex = String(filtered[filtered.index(start, offsetBy: 2) ..< filtered.index(start, offsetBy: 4)])
        let blueHex = String(filtered[filtered.index(start, offsetBy: 4) ..< filtered.index(start, offsetBy: 6)])
        let red = hexComponentValue(redHex) / 255
        let green = hexComponentValue(greenHex) / 255
        let blue = hexComponentValue(blueHex) / 255
        return Color(red: red, green: green, blue: blue)
    }

    private static func hexComponentValue(_ hex: String) -> Double {
        #if SKIP
        return Double(java.lang.Integer.parseInt(hex, 16))
        #else
        return Double(Int(hex, radix: 16) ?? 0)
        #endif
    }
}
