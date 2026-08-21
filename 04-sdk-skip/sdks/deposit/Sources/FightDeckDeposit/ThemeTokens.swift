//
// ThemeTokens.swift
// FightDeckDeposit
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import Foundation
import SwiftUI

public struct ThemeTokens: Sendable {
    public let background: Color
    public let surface: Color
    public let surfaceElevated: Color
    public let textPrimary: Color
    public let textSecondary: Color
    public let accent: Color
    public let onAccent: Color
    public let positive: Color
    public let negative: Color

    public let spacingLG: CGFloat
    public let spacingMD: CGFloat
    public let spacingSM: CGFloat
    public let spacingXL: CGFloat
    public let radiusLG: CGFloat
    public let radiusMD: CGFloat
    public let fontBody: CGFloat
    public let fontCaption: CGFloat
    public let fontCallout: CGFloat
    public let fontTitle: CGFloat
    public let fontDisplay: CGFloat

    public static let defaults = ThemeTokens(
        background: ThemeColor.fromHex("#0B0E14"),
        surface: ThemeColor.fromHex("#141922"),
        surfaceElevated: ThemeColor.fromHex("#1C2230"),
        textPrimary: ThemeColor.fromHex("#F5F7FA"),
        textSecondary: ThemeColor.fromHex("#9AA5B8"),
        accent: ThemeColor.fromHex("#E8B33C"),
        onAccent: ThemeColor.fromHex("#0B0E14"),
        positive: ThemeColor.fromHex("#3DD68C"),
        negative: ThemeColor.fromHex("#F2545B"),
        spacingLG: 16,
        spacingMD: 12,
        spacingSM: 8,
        spacingXL: 24,
        radiusLG: 16,
        radiusMD: 12,
        fontBody: 15,
        fontCaption: 12,
        fontCallout: 17,
        fontTitle: 22,
        fontDisplay: 34
    )

    public static func parse(_ themeJSON: String) -> ThemeTokens {
        guard let data = themeJSON.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let colors = root["color"] as? [String: Any] else {
            return .defaults
        }
        func hex(_ key: String, fallback: String) -> Color {
            guard let entry = colors[key] as? [String: Any],
                  let value = entry["$value"] as? [String: Any],
                  let hexValue = value["hex"] as? String else {
                return ThemeColor.fromHex(fallback)
            }
            return ThemeColor.fromHex(hexValue)
        }
        return ThemeTokens(
            background: hex("background", fallback: "#0B0E14"),
            surface: hex("surface", fallback: "#141922"),
            surfaceElevated: hex("surfaceElevated", fallback: "#1C2230"),
            textPrimary: hex("textPrimary", fallback: "#F5F7FA"),
            textSecondary: hex("textSecondary", fallback: "#9AA5B8"),
            accent: hex("accent", fallback: "#E8B33C"),
            onAccent: hex("onAccent", fallback: "#0B0E14"),
            positive: hex("positive", fallback: "#3DD68C"),
            negative: hex("negative", fallback: "#F2545B"),
            spacingLG: 16,
            spacingMD: 12,
            spacingSM: 8,
            spacingXL: 24,
            radiusLG: 16,
            radiusMD: 12,
            fontBody: 15,
            fontCaption: 12,
            fontCallout: 17,
            fontTitle: 22,
            fontDisplay: 34
        )
    }
}

enum ThemeColor {
    static func fromHex(_ hex: String) -> Color {
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
