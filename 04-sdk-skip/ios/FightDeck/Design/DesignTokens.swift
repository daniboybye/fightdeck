//
// DesignTokens.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import SwiftUI

/// Only the values the system cannot supply live here. Type sizes come from `Font` so the
/// app scales with Dynamic Type, and surfaces come from the grouped-list backgrounds so
/// Liquid Glass has something real to sample.
///
/// The sizes below are the host's own and deliberately differ from Android's: 44pt is the
/// Human Interface Guidelines' tap target, Material's is 48dp. The *colours* are not the
/// host's — they come from the SDK's `Palette`, which is the only place a FightDeck colour
/// is written down.
enum DesignTokens {
    enum ColorToken {
        static let accent = ThemeColor.fromHex(Palette.accent)
        static let onAccent = ThemeColor.fromHex(Palette.onAccent)
        static let positive = ThemeColor.fromHex(Palette.positive)
        static let cornerRed = ThemeColor.fromHex(Palette.cornerRed)
        static let cornerBlue = ThemeColor.fromHex(Palette.cornerBlue)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }

    enum Layout {
        /// The floor the Human Interface Guidelines put on any control you can tap. Button
        /// styles size to their label, which lands well under it for a one-line title.
        static let minTapTarget: CGFloat = 44
        /// Chips, keyboard dismissal and the confirmation acknowledgement — present enough to
        /// hit, quiet enough not to compete with the primary action.
        static let secondaryActionHeight: CGFloat = 44
        /// Horizontal breathing room for a button that hugs its label instead of filling a bar.
        static let secondaryActionPadding: CGFloat = 24
        /// What an odds pill asks for before the bordered style pads it out to the tap target.
        static let oddsLabelHeight: CGFloat = 30
        static let mediaTileAspectRatio: CGFloat = 16 / 9
        static let betSlipAccessoryHeight: CGFloat = 44
    }
}
