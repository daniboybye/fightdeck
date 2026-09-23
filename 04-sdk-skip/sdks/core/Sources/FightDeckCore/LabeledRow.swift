//
// LabeledRow.swift
// FightDeckCore
//
// Created by FightDeck on 21.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI

/// A label on the left, its value on the right — the `LabeledContent` row that SkipUI has no
/// mapping for. All three SDK screens need it, so it lives here rather than three times over.
///
/// One struct with one `body`, and **no `Renderable`**. An earlier version of this file
/// conformed to `Renderable` and implemented `Render(context:)`, on the belief that a view of
/// ours implementing only `body` composed to nothing on Android. That belief was wrong: the
/// real cause was `skipstone` dropping a bare initialiser written straight into a
/// `@ViewBuilder` — see `GroupedList.swift`. Once every screen reaches this type through a
/// function, a plain `body` renders on both platforms. Verified on a device, not assumed.
///
/// The `#if` is the whole of what is left, and it buys real iOS behaviour: `LabeledContent`
/// reads its label and value to VoiceOver as one element and restacks them at large Dynamic
/// Type sizes. `.accessibilityElement(children:)` — the portable way to get the first of
/// those back — has no SkipUI mapping, so dropping the `#if` would trade a native iOS row
/// for four fewer lines. Not a trade worth making.
public struct LabeledRow: View {
    let theme: ThemeTokens
    let label: String
    let value: String
    let valueStyle: Color

    public init(theme: ThemeTokens, label: String, value: String, valueStyle: Color) {
        self.theme = theme
        self.label = label
        self.value = value
        self.valueStyle = valueStyle
    }

    public var body: some View {
        #if SKIP
        HStack {
            Text(label)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(valueStyle)
        }
        .font(Typography.body(theme.fontBody))
        #else
        LabeledContent(label, value: value)
        #endif
    }
}
