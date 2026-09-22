//
// MaterialScheme.swift
// FightDeckCore
//
// Created by FightDeck on 21.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

#if SKIP
import SwiftUI

/// The host app's `MaterialTheme` does not reach the SDK screens. SkipUI installs one of its own
/// around every view it renders: `ColorScheme.asMaterialTheme()` builds it from
/// `dynamicDarkColorScheme(context)` on Android 12 and up, so the transpiled screens came out in
/// whatever Material You derived from the device wallpaper, and fell back to a *light* scheme
/// whenever the device was not in dark mode. That is why the Skip screens carried a different
/// background from the rest of the app.
///
/// `material3ColorScheme` is the documented way in: it is the one hook SkipUI reads before
/// handing the scheme to its `MaterialTheme`. The closure receives Skip's default scheme and the
/// requested dark flag, and both are deliberately ignored here — FightDeck has a single dark
/// palette, so starting from `darkColorScheme` rather than patching the default keeps the result
/// the same on a light-mode device and on one with no dynamic colour at all.
///
/// The field list mirrors the host's own `darkColorScheme` in `FightDeckApp.kt`. Keep the two in
/// step: the point of this function is that an SDK screen and a hand-written Compose screen
/// beside it resolve `MaterialTheme.colorScheme` to the same values.
@Composable public func fightDeckColorScheme(_ theme: ThemeTokens) -> androidx.compose.material3.ColorScheme {
    return androidx.compose.material3.darkColorScheme(
        primary: theme.accent.asComposeColor(),
        onPrimary: theme.onAccent.asComposeColor(),
        secondary: theme.accent.asComposeColor(),
        onSecondary: theme.onAccent.asComposeColor(),
        // The selected navigation item, FilledTonalButton and the keyboard's Done button all
        // read this pair. Left at the Material default they come back lavender.
        secondaryContainer: theme.surfaceElevated.asComposeColor(),
        onSecondaryContainer: theme.accent.asComposeColor(),
        // `background`, counter-intuitively, is what a grouped `List` paints its *rows* with:
        // SkipUI's `List.BackgroundColor(isItem: true)` returns `Color.background`, which maps
        // straight to this field. The page behind the rows is the root's own
        // `.background(theme.background)`, shown through `.scrollContentBackground(.hidden)`.
        background: theme.surface.asComposeColor(),
        onBackground: theme.textPrimary.asComposeColor(),
        surface: theme.surface.asComposeColor(),
        onSurface: theme.textPrimary.asComposeColor(),
        // Material tints elevated surfaces towards `surfaceTint`, which defaults to `primary` —
        // gold here, so every raised surface came back faintly warm. Pointing it at `surface`
        // makes `surfaceColorAtElevation` flat at any elevation.
        surfaceTint: theme.surface.asComposeColor(),
        surfaceVariant: theme.surfaceElevated.asComposeColor(),
        onSurfaceVariant: theme.textSecondary.asComposeColor(),
        // A grouped list draws its rows on surfaceContainer and its scrolled-under bars on the
        // High tone, so both have to be said or the cards float on stock Material grey.
        surfaceContainer: theme.surface.asComposeColor(),
        surfaceContainerHigh: theme.surfaceElevated.asComposeColor(),
        surfaceContainerHighest: theme.surfaceElevated.asComposeColor(),
        error: theme.negative.asComposeColor(),
        outline: theme.textSecondary.asComposeColor(),
        outlineVariant: theme.textSecondary.asComposeColor()
    )
}
#endif
