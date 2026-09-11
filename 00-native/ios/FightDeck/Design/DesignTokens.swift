//
// DesignTokens.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI

/// Only the values the system cannot supply. Type sizes come from `Font` so the app scales
/// with Dynamic Type, and surfaces come from the grouped-list backgrounds.
enum DesignTokens {
    enum ColorToken {
        static let accent = Color(hex: "#E8B33C")
        static let onAccent = Color(hex: "#0B0E14")
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

    /// 44pt is the Human Interface Guidelines floor for anything tappable, and also the
    /// ceiling for a button: taller reads as a banner.
    enum Layout {
        static let minTapTarget: CGFloat = 44
        static let primaryActionHeight: CGFloat = 44
        static let secondaryActionHeight: CGFloat = 44
        static let secondaryActionPadding: CGFloat = 24
        static let actionBarGap: CGFloat = 12
        /// What an odds pill asks for before the bordered style pads it out to the tap target.
        static let oddsLabelHeight: CGFloat = 30
        static let mediaTileAspectRatio: CGFloat = 16 / 9
        static let betSlipAccessoryHeight: CGFloat = 44
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
