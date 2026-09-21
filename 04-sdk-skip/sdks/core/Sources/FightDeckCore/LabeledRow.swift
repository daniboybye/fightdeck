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
/// On Android it is written the way SkipUI writes its own components, and that is the point:
/// conform to `Renderable` and implement `Render(context:)` rather than leaving the work to
/// `body`. A view of ours that only implemented `body` composed to nothing when placed among
/// siblings — which is what sent the earlier attempt at shared rows back into each screen.
#if SKIP
public struct LabeledRow: View, Renderable {
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

    @Composable public override func Render(context: ComposeContext) {
        HStack {
            Text(label)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(valueStyle)
        }
        .font(Typography.body(theme.fontBody))
        .Compose(context: context)
    }
}
#else
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
        LabeledContent(label, value: value)
    }
}
#endif
