//
// ThemeTokens.swift
// FightDeckCore
//
// Created by FightDeck on 18.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI

/// Shared screen theme for the Skip SDKs. Values match `shared-ui-spec/tokens.json`, held as
/// typed fields rather than re-parsed JSON on every present — Skip can pass a struct across
/// the host/SDK boundary, unlike React Native which has to serialise.
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
    public let spacingXS: CGFloat
    public let spacingXL: CGFloat
    public let radiusLG: CGFloat
    public let radiusMD: CGFloat
    public let fontBody: CGFloat
    public let fontCaption: CGFloat
    public let fontCallout: CGFloat
    public let fontTitle: CGFloat
    public let fontDisplay: CGFloat

    public init(
        background: Color,
        surface: Color,
        surfaceElevated: Color,
        textPrimary: Color,
        textSecondary: Color,
        accent: Color,
        onAccent: Color,
        positive: Color,
        negative: Color,
        spacingLG: CGFloat,
        spacingMD: CGFloat,
        spacingSM: CGFloat,
        spacingXS: CGFloat,
        spacingXL: CGFloat,
        radiusLG: CGFloat,
        radiusMD: CGFloat,
        fontBody: CGFloat,
        fontCaption: CGFloat,
        fontCallout: CGFloat,
        fontTitle: CGFloat,
        fontDisplay: CGFloat
    ) {
        self.background = background
        self.surface = surface
        self.surfaceElevated = surfaceElevated
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.accent = accent
        self.onAccent = onAccent
        self.positive = positive
        self.negative = negative
        self.spacingLG = spacingLG
        self.spacingMD = spacingMD
        self.spacingSM = spacingSM
        self.spacingXS = spacingXS
        self.spacingXL = spacingXL
        self.radiusLG = radiusLG
        self.radiusMD = radiusMD
        self.fontBody = fontBody
        self.fontCaption = fontCaption
        self.fontCallout = fontCallout
        self.fontTitle = fontTitle
        self.fontDisplay = fontDisplay
    }

    public static let defaults = ThemeTokens(
        background: ThemeColor.fromHex(Palette.background),
        surface: ThemeColor.fromHex(Palette.surface),
        surfaceElevated: ThemeColor.fromHex(Palette.surfaceElevated),
        textPrimary: ThemeColor.fromHex(Palette.textPrimary),
        textSecondary: ThemeColor.fromHex(Palette.textSecondary),
        accent: ThemeColor.fromHex(Palette.accent),
        onAccent: ThemeColor.fromHex(Palette.onAccent),
        positive: ThemeColor.fromHex(Palette.positive),
        negative: ThemeColor.fromHex(Palette.negative),
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

    public var chipTheme: SkipChipTheme {
        SkipChipTheme(
            accent: accent,
            surfaceElevated: surfaceElevated,
            spacingSM: spacingSM,
            fontCaption: fontCaption
        )
    }
}

/// The SDK screens read their theme from the environment instead of taking it as an argument
/// the host always filled in with `ThemeTokens.defaults`. A host with a palette of its own sets
/// `.environment(\.fightDeckTheme, …)` once, above whatever SDK screens it mounts.
struct FightDeckThemeKey: EnvironmentKey {
    static let defaultValue = ThemeTokens.defaults
}

extension EnvironmentValues {
    public var fightDeckTheme: ThemeTokens {
        get { self[FightDeckThemeKey.self] }
        set { self[FightDeckThemeKey.self] = newValue }
    }
}
