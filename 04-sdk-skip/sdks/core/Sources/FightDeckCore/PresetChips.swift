//
// PresetChips.swift
// FightDeckCore
//
// Created by FightDeck on 28.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI

public struct SkipChipTheme: Sendable {
    public let accent: Color
    public let surfaceElevated: Color
    public let spacingSM: CGFloat
    public let fontCaption: CGFloat
    public let secondaryActionHeight: CGFloat

    public init(
        accent: Color,
        surfaceElevated: Color,
        spacingSM: CGFloat,
        fontCaption: CGFloat,
        secondaryActionHeight: CGFloat = 44
    ) {
        self.accent = accent
        self.surfaceElevated = surfaceElevated
        self.spacingSM = spacingSM
        self.fontCaption = fontCaption
        self.secondaryActionHeight = secondaryActionHeight
    }
}

#if !SKIP && os(iOS)
public struct PresetChipRow<Content: View>: View {
    let theme: SkipChipTheme
    @ViewBuilder var content: () -> Content

    public init(theme: SkipChipTheme, @ViewBuilder content: @escaping () -> Content) {
        self.theme = theme
        self.content = content
    }

    public var body: some View {
        GlassEffectContainer(spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                content()
            }
        }
    }
}

public struct PresetChipButton: View {
    let title: String
    let theme: SkipChipTheme
    let action: () -> Void

    public init(title: String, theme: SkipChipTheme, action: @escaping () -> Void) {
        self.title = title
        self.theme = theme
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: theme.secondaryActionHeight)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}
#endif
