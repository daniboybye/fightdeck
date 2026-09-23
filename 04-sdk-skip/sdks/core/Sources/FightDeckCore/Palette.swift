//
// Palette.swift
// FightDeckCore
//
// Created by FightDeck on 23.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

/// The one place a FightDeck colour is written down.
///
/// It was three: `ThemeTokens.defaults` for the values that cross into the SDK screens, and
/// then each host's own token file again, because neither could use the SDK's `Color`.
/// SkipUI's `Color` reaches its Compose counterpart only through `colorImpl`, which is
/// `@Composable` — so an Android `object Tokens` cannot hold one as a plain constant, and
/// the palette got retyped rather than shared.
///
/// Hex strings cross without any of that. They transpile to Kotlin `String`, need no
/// composable scope, and each side still builds its own native colour type: `Color` on iOS,
/// `androidx.compose.ui.graphics.Color` on Android, SkipUI's `Color` inside `ThemeTokens`.
/// Three colour types, one set of values.
///
/// This is not a line-count saving — it is roughly a wash. What it removes is the way three
/// copies drift.
public enum Palette {
    public static let background = "#0B0E14"
    public static let surface = "#141922"
    public static let surfaceElevated = "#1C2230"
    public static let textPrimary = "#F5F7FA"
    public static let textSecondary = "#9AA5B8"
    public static let accent = "#E8B33C"
    public static let onAccent = "#0B0E14"
    public static let positive = "#3DD68C"
    public static let negative = "#F2545B"

    /// Corner colours never cross into an SDK screen — no shared screen draws a fighter's
    /// corner — but they are part of the same palette and drifted in the same way.
    public static let cornerRed = "#D94A4A"
    public static let cornerBlue = "#4A7FD9"
}
