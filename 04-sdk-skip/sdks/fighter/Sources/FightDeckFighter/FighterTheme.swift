//
// FighterTheme.swift
// FightDeckFighter
//
// Created by FightDeck on 13.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import Foundation
import SwiftUI

public struct FighterTheme: Sendable {
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
    public let spacingXS: CGFloat
    public let spacingXL: CGFloat
    public let radiusLG: CGFloat
    public let radiusMD: CGFloat
    public let fontBody: CGFloat
    public let fontCaption: CGFloat
    public let fontCallout: CGFloat
    public let fontTitle: CGFloat
    public let fontDisplay: CGFloat

    public static let defaults = FighterTheme(
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
        spacingXS: 4,
        spacingXL: 24,
        radiusLG: 16,
        radiusMD: 12,
        fontBody: 15,
        fontCaption: 12,
        fontCallout: 17,
        fontTitle: 22,
        fontDisplay: 34
    )

    public static func parse(_ themeJSON: String) -> FighterTheme {
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
        return FighterTheme(
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
            spacingXS: 4,
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
