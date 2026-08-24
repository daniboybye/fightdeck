//
// DesignTokens.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI

/// Only the values the system cannot supply live here. Type sizes come from `Font` so the
/// app scales with Dynamic Type, and surfaces come from the grouped-list backgrounds so
/// Liquid Glass has something real to sample.
enum DesignTokens {
    enum ColorToken {
        static let accent = Color(hex: "#E8B33C")
        static let positive = Color(hex: "#3DD68C")
        static let negative = Color(hex: "#F2545B")
        static let cornerRed = Color(hex: "#D94A4A")
        static let cornerBlue = Color(hex: "#4A7FD9")
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
        /// A full-width call to action reads as a button, not a label, at this height.
        static let primaryActionHeight: CGFloat = 50
    }
}

extension View {
    /// Grows a control to the 44pt tap-target floor without changing how it looks.
    func minimumTapTarget() -> some View {
        frame(minHeight: DesignTokens.Layout.minTapTarget)
            .contentShape(.rect)
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
