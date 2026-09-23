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

    /// The font an Android `Section` header wants, and the reason it wants one at all.
    ///
    /// Left to itself, SkipUI dresses a section header the way *iOS* dresses one: small, grey
    /// and UPPER-CASED. The hand-written Compose screens beside these write theirs in ordinary
    /// title case at `MaterialTheme.typography.titleMedium`, so the SDK screens looked foreign
    /// next to them.
    ///
    /// The upper-casing is not a modifier to switch off — it lives in `Text.styleInfo`:
    ///
    ///     if let environmentFont = EnvironmentValues.shared.font { font = environmentFont }
    ///     else if let sectionHeaderStyle = … { font = .callout; isUppercased = true }
    ///
    /// A header keeps its own case for exactly one reason: that a font was set. Setting one is
    /// therefore the whole fix, and 17pt medium is where Material's `titleMedium` lands. The
    /// colour is deliberately left alone — SkipUI's `Color.secondary` already resolves to the
    /// `onSurfaceVariant` the native headers use.
    ///
    /// Only the Android side reads this. On iOS a section header is SwiftUI's to style, and
    /// leaving it alone is what keeps that screen unchanged.
    public static func sectionHeader(_ theme: ThemeTokens) -> Font {
        medium(theme.fontCallout)
    }
}
