//
// MaterialScheme.swift
// FightDeckCore
//
// Created by FightDeck on 21.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI

/// What every SDK screen puts around itself so that it draws in the FightDeck palette on
/// Android: `.modifier(FightDeckScreen(theme: theme))`. On iOS the screen is real SwiftUI and
/// takes its colours from the tokens directly, so this does nothing there.
///
/// A `ViewModifier` rather than a `View` extension on purpose. An extension of ours at the end
/// of a `@ViewBuilder` chain transpiles without the `.Compose(composectx)` that SkipUI's own
/// modifiers get — the deposit body failed to compile with "expected 'ComposeResult', actual
/// 'View'" — while `.modifier(_:)` is SkipUI's and is composed like any other.
public struct FightDeckScreen: ViewModifier {
    let theme: ThemeTokens

    public init(theme: ThemeTokens) {
        self.theme = theme
    }

    public func body(content: Content) -> some View {
        #if SKIP
        content.material3ColorScheme { _, _ in fightDeckColorScheme(theme) }
        #else
        content
        #endif
    }
}

#if SKIP
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
/// This is not the host's scheme, and it deliberately does not replace it. The two agree on the
/// accent, the surfaces and the tonal-button pair, but not on `background` — rows here, the
/// page behind them in the host — and the host leaves the text and outline roles at Material's
/// defaults, the same ones `00-native` uses. One definition for both would recolour the host's
/// own screens.
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
