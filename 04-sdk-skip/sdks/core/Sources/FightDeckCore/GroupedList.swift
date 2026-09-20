//
// GroupedList.swift
// FightDeckCore
//
// Created by FightDeck on 20.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI

#if SKIP
/// The inset-grouped list, drawn by hand. SkipUI maps `List` to a plain Compose list with no
/// grouped style, so the betslip and fighter screens each built the same card-with-dividers
/// stack; this is that stack, in the one place both SDKs already depend on.
public struct GroupedSection<Content: View>: View {
    let theme: ThemeTokens
    let title: String?
    @ViewBuilder var content: () -> Content

    public init(
        theme: ThemeTokens,
        title: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.theme = theme
        self.title = title
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            if let title {
                Text(title)
                    .font(Typography.body(theme.fontCallout))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, theme.spacingLG)
            }
            VStack(spacing: 0) {
                content()
            }
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLG))
        }
    }
}

/// One row of a `GroupedSection`. The divider belongs to the row above it, which is why the
/// last row has to say so rather than the section counting its children — a `ViewBuilder`
/// hands over opaque content, not a list to measure.
public struct GroupedRow<Content: View>: View {
    let theme: ThemeTokens
    let isLast: Bool
    let compact: Bool
    @ViewBuilder var content: () -> Content

    public init(
        theme: ThemeTokens,
        isLast: Bool,
        compact: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.theme = theme
        self.isLast = isLast
        self.compact = compact
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            content()
                .padding(.horizontal, theme.spacingLG)
                .padding(.vertical, compact ? theme.spacingSM : theme.spacingMD)
            if !isLast {
                Rectangle()
                    .fill(theme.textSecondary.opacity(0.25))
                    .frame(height: 1)
                    .padding(.leading, theme.spacingLG)
            }
        }
    }
}

/// A label on the left, its value on the right — the `LabeledContent` row that SkipUI has no
/// Material equivalent for.
public struct GroupedLabeledRow: View {
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
        HStack {
            Text(label)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(valueStyle)
        }
        .font(Typography.body(theme.fontBody))
    }
}
#endif
