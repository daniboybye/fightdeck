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

/// One chip, both platforms. Liquid Glass is iOS's and has no Android equivalent, so the
/// Android branch draws the capsule the Material way — but the size, the label and the tap
/// target are written once.
///
/// This used to be `#if !SKIP` in its entirety, with each Android screen drawing its own
/// chips inline, on the belief that a shared view of ours would not render there. It renders.
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
                .font(chipFont)
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: theme.secondaryActionHeight)
            #if !SKIP
                .contentShape(.capsule)
            #endif
        }
        #if SKIP
        .background(theme.surfaceElevated)
        .clipShape(Capsule())
        #else
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        #endif
    }

    #if SKIP
    private var chipFont: Font { Typography.medium(theme.fontCaption) }
    #else
    private var chipFont: Font { .subheadline.weight(.semibold) }
    #endif
}

/// The container stays iOS-only: `GlassEffectContainer` is what makes neighbouring chips
/// share one glass surface, and Android has nothing to group.
#if !SKIP
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
#endif
